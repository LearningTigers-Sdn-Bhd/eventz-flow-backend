require 'rails_helper'

RSpec.describe JwtService do
  let(:user) { create(:user) }
  let(:request) { double('Request', remote_ip: '127.0.0.1', user_agent: 'TestBot') }

  describe '.generate_tokens' do
    it 'generates access and refresh tokens' do
      tokens = described_class.generate_tokens(user, request)
      
      expect(tokens).to have_key(:access_token)
      expect(tokens).to have_key(:refresh_token)
      expect(tokens).to have_key(:expires_at)
      expect(tokens).to have_key(:session_id)
    end

    it 'creates a new user session' do
      expect {
        described_class.generate_tokens(user, request)
      }.to change(UserSession, :count).by(1)
    end

    it 'stores correct session data' do
      tokens = described_class.generate_tokens(user, request)
      session = UserSession.find(tokens[:session_id])

      expect(session.user).to eq(user)
      expect(session.ip_address).to eq('127.0.0.1')
      # user_agent "TestBot" -> "Unknown Device" because regex in JwtService doesn't match TestBot
      expect(session.user_agent).to eq('TestBot')
      expect(session.expires_at).to be > Time.current
      expect(session.refresh_token_hash).to eq(described_class.hash_token(tokens[:refresh_token]))
    end

    it 'embeds the same jti in access and refresh tokens' do
      tokens = described_class.generate_tokens(user, request)
      access_payload = described_class.decode(tokens[:access_token])
      refresh_payload = described_class.decode(tokens[:refresh_token])
      session = UserSession.find(tokens[:session_id])

      expect(access_payload[:jti]).to eq(session.jti)
      expect(refresh_payload[:jti]).to eq(session.jti)
    end
  end

  describe '.refresh_access_token' do
    let!(:tokens) { described_class.generate_tokens(user, request) }
    let(:refresh_token) { tokens[:refresh_token] }

    it 'rotates tokens and updates session without changing the session jti' do
      original_session = UserSession.find(tokens[:session_id])
      original_jti = original_session.jti
      original_hash = original_session.refresh_token_hash

      new_tokens = described_class.refresh_access_token(refresh_token, request)
      original_session.reload

      expect(new_tokens[:refresh_token]).not_to eq(tokens[:refresh_token])
      
      # Session updated, not created
      expect(UserSession.count).to eq(1)
      expect(original_session.jti).to eq(original_jti)
      expect(original_session.refresh_token_hash).not_to eq(original_hash)
      expect(original_session.refresh_token_hash).to eq(described_class.hash_token(new_tokens[:refresh_token]))
    end

    it 'keeps existing access tokens valid after refresh rotation' do
      original_access_payload = described_class.decode(tokens[:access_token])

      described_class.refresh_access_token(refresh_token, request)

      expect(UserSession.find_by(jti: original_access_payload[:jti], user_id: user.id)).to be_active
    end

    it 'locks the matching session while rotating the refresh token' do
      expect(UserSession).to receive(:transaction).and_call_original
      expect(UserSession).to receive(:lock).and_call_original

      described_class.refresh_access_token(refresh_token, request)
    end

    it 'raises error for invalid refresh token' do
      expect {
        described_class.refresh_access_token('invalid_token', request)
      }.to raise_error(CustomError::Unauthorized, 'Invalid token')
    end

    it 'raises error for revoked session' do
      session = UserSession.find(tokens[:session_id])
      session.revoke!

      expect {
        described_class.refresh_access_token(refresh_token, request)
      }.to raise_error(CustomError::Unauthorized, 'Invalid or expired session')
    end
    
    it 'raises error if refresh token does not match session hash' do
        # Manually create a token with correct structure but wrong content for the session
        fake_payload = { user_id: user.id, jti: SecureRandom.uuid, type: 'refresh' }
        fake_token = described_class.encode(fake_payload)
        
        expect {
            described_class.refresh_access_token(fake_token, request)
        }.to raise_error(CustomError::Unauthorized, 'Invalid or expired session')
    end
  end

  describe '.decode' do
    it 'decodes valid token' do
      token = described_class.encode({ data: 'test' })
      payload = described_class.decode(token)
      expect(payload[:data]).to eq('test')
    end

    it 'raises error for expired token' do
      token = described_class.encode({ data: 'test' }, 1.minute.ago)
      expect {
        described_class.decode(token)
      }.to raise_error(CustomError::Unauthorized, 'Token has expired')
    end
  end
end
