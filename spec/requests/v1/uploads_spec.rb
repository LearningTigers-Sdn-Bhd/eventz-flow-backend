require 'swagger_helper'

RSpec.describe 'V1::Uploads', type: :request do
  # ============================================================
  # Shared Constants & Schemas
  # ============================================================
  UPLOAD_SUCCESS_SCHEMA = {
    type: :object,
    properties: {
      success: { type: :boolean, example: true },
      message: { type: :string, example: 'Success' },
      data: {
        type: :object,
        properties: {
          url: { type: :string, description: 'Permanent URL to the uploaded file' },
          signed_id: { type: :string, description: 'Signed ID for ActiveStorage' },
          filename: { type: :string, description: 'Original filename' },
          content_type: { type: :string, description: 'MIME type of the file' },
          byte_size: { type: :integer, description: 'File size in bytes' }
        },
        required: %w[url signed_id filename content_type byte_size]
      }
    },
    required: %w[success message data]
  }.freeze

  UPLOAD_ERROR_SCHEMA = {
    type: :object,
    properties: {
      success: { type: :boolean, example: false },
      message: { type: :string, example: 'File size exceeds maximum allowed size of 10MB' },
      errors: { type: :array, items: { type: :string } }
    },
    required: %w[success message]
  }.freeze

  # ============================================================
  # Setup
  # ============================================================
  let(:user) { create(:user, :organizer) }
  let(:auth_header) { auth_headers(user)['Authorization'] }

  # Helper to create test image file
  def create_test_image(filename: 'test.jpg', content_type: 'image/jpeg', size: nil)
    file_path = Rails.root.join('spec', 'fixtures', 'test_image.png')

    # If size is specified, create a file of that size
    if size && size > File.size(file_path)
      temp_file = Tempfile.new([File.basename(filename, '.*'), File.extname(filename)])
      FileUtils.cp(file_path, temp_file.path)
      # Pad file to reach desired size
      File.open(temp_file.path, 'a') { |f| f.write('0' * (size - File.size(temp_file.path))) }
      temp_file.rewind
      uploaded_file = Rack::Test::UploadedFile.new(temp_file.path, content_type)
      # Store temp_file reference to prevent garbage collection
      @temp_files ||= []
      @temp_files << temp_file
      uploaded_file
    elsif filename.end_with?('.png')
      fixture_file_upload(file_path, 'image/png')
    else
      # Copy fixture and rename for different extensions
      temp_file = Tempfile.new([File.basename(filename, '.*'), File.extname(filename)])
      FileUtils.cp(file_path, temp_file.path)
      temp_file.rewind
      @temp_files ||= []
      @temp_files << temp_file
      Rack::Test::UploadedFile.new(temp_file.path, content_type)
    end
  end

  # Helper to check if vips is available
  def vips_available?
    @vips_available ||= begin
      require 'vips'
      Vips::Image.black(1, 1)
      true
    rescue LoadError, NoMethodError
      false
    end
  end

  # ============================================================
  # POST /v1/uploads
  # ============================================================
  path '/v1/uploads' do
    post('upload file') do
      tags 'Generic Uploads'
      consumes 'multipart/form-data'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :file, in: :formData, type: :file, required: true, description: 'File to upload'
      parameter name: :target, in: :formData, type: :string, required: false,
                description: 'Target identifier (rich-editor, resources, general)'

      response(200, 'successful upload for rich-editor') do
        schema UPLOAD_SUCCESS_SCHEMA
        let(:Authorization) { auth_header }
        let(:file) { create_test_image(filename: 'test.jpg', content_type: 'image/jpeg') }
        let(:target) { 'rich-editor' }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['data']).to be_present
          expect(json['data']['url']).to be_present
          expect(json['data']['signed_id']).to be_present
          expect(json['data']['filename']).to be_present
          expect(json['data']['content_type']).to be_present
          expect(json['data']['byte_size']).to be > 0

          # For rich-editor, if vips is available, should be optimized (WebP)
          if vips_available?
            expect(json['data']['content_type']).to eq('image/webp')
            expect(json['data']['filename']).to match(/\.webp$/)
          end
        end
      end

      response(200, 'successful upload for resources') do
        schema UPLOAD_SUCCESS_SCHEMA
        let(:Authorization) { auth_header }
        let(:file) { create_test_image(filename: 'resource.jpg', content_type: 'image/jpeg') }
        let(:target) { 'resources' }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['data']).to be_present
          expect(json['data']['content_type']).to be_present
        end
      end

      response(200, 'successful upload for general') do
        schema UPLOAD_SUCCESS_SCHEMA
        let(:Authorization) { auth_header }
        let(:file) { create_test_image(filename: 'document.jpg', content_type: 'image/jpeg') }
        let(:target) { 'general' }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['data']).to be_present
        end
      end

      response(200, 'successful upload with default target') do
        schema UPLOAD_SUCCESS_SCHEMA
        let(:Authorization) { auth_header }
        let(:file) { create_test_image(filename: 'test.jpg', content_type: 'image/jpeg') }
        # target not specified, should default to 'general'

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['data']).to be_present
        end
      end

      response(422, 'unprocessable entity - no file provided') do
        schema UPLOAD_ERROR_SCHEMA
        let(:Authorization) { auth_header }
        let(:file) { nil }
        let(:target) { 'rich-editor' }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['success']).to be false
          expect(json['message']).to include('No file provided')
        end
      end

      response(422, 'unprocessable entity - file size exceeds limit for rich-editor') do
        schema UPLOAD_ERROR_SCHEMA
        let(:Authorization) { auth_header }
        # Create a file larger than 10MB (rich-editor limit)
        # Use a smaller size for testing (10.5MB is enough to test the limit)
        let(:file) do
          temp_file = Tempfile.new(['large', '.jpg'])
          temp_file.write('0' * (10.5 * 1024 * 1024)) # 10.5MB
          temp_file.rewind
          Rack::Test::UploadedFile.new(temp_file.path, 'image/jpeg')
        end
        let(:target) { 'rich-editor' }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['success']).to be false
          expect(json['message']).to include('File size exceeds maximum allowed size')
        end
      end

      response(422, 'unprocessable entity - file size exceeds limit for resources') do
        schema UPLOAD_ERROR_SCHEMA
        let(:Authorization) { auth_header }
        let(:file) do
          temp_file = Tempfile.new(['large', '.jpg'])
          temp_file.write('0' * (10.5 * 1024 * 1024)) # 10.5MB
          temp_file.rewind
          Rack::Test::UploadedFile.new(temp_file.path, 'image/jpeg')
        end
        let(:target) { 'resources' }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['success']).to be false
          expect(json['message']).to include('File size exceeds maximum allowed size')
        end
      end

      response(422, 'unprocessable entity - invalid file type for rich-editor') do
        schema UPLOAD_ERROR_SCHEMA
        let(:Authorization) { auth_header }
        # Create a non-image file
        let(:file) do
          temp_file = Tempfile.new(['test', '.txt'])
          temp_file.write('Not an image')
          temp_file.rewind
          Rack::Test::UploadedFile.new(temp_file.path, 'text/plain')
        end
        let(:target) { 'rich-editor' }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['success']).to be false
          expect(json['message']).to include('not allowed')
        end
      end

      response(401, 'unauthorized - no token') do
        let(:Authorization) { nil }
        let(:file) { create_test_image }
        let(:target) { 'rich-editor' }

        run_test! do |response|
          expect(response.status).to eq(401)
        end
      end
    end
  end

  # ============================================================
  # Rich Editor Image Optimization Tests
  # ============================================================
  describe 'Rich Editor Image Optimization' do
    let(:auth_header) { auth_headers(user)['Authorization'] }

    context 'when vips is available' do
      before do
        # Skip if vips is not available
        skip 'Vips not available' unless vips_available?
      end

      it 'resizes large images to max 2400x2400px' do
        # Create a large image (using the test fixture)
        file = fixture_file_upload(Rails.root.join('spec', 'fixtures', 'test_image.png'), 'image/png')

        post '/v1/uploads', params: { file: file, target: 'rich-editor' },
             headers: { 'Authorization' => auth_header }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        if json['data']['content_type'] == 'image/webp'
          # Verify the blob exists and check dimensions
          blob = ActiveStorage::Blob.find_signed(json['data']['signed_id'])
          expect(blob).to be_present

          # Download and check dimensions using vips
          require 'vips'
          blob.open do |temp_file|
            image = Vips::Image.new_from_file(temp_file.path)
            expect(image.width).to be <= 2400
            expect(image.height).to be <= 2400
          end
        end
      end

      it 'converts images to WebP format' do
        file = fixture_file_upload(Rails.root.join('spec', 'fixtures', 'test_image.png'), 'image/png')

        post '/v1/uploads', params: { file: file, target: 'rich-editor' },
             headers: { 'Authorization' => auth_header }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['data']['content_type']).to eq('image/webp')
        expect(json['data']['filename']).to match(/\.webp$/)
      end
    end

    context 'when vips is not available' do
      before do
        allow_any_instance_of(V1::UploadsController).to receive(:vips_available?).and_return(false)
      end

      it 'still uploads successfully without optimization' do
        file = fixture_file_upload(Rails.root.join('spec', 'fixtures', 'test_image.png'), 'image/png')

        post '/v1/uploads', params: { file: file, target: 'rich-editor' },
             headers: { 'Authorization' => auth_header }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['data']).to be_present
        # File should remain in original format
        expect(json['data']['content_type']).to eq('image/png')
      end
    end
  end

  # ============================================================
  # Metadata Tracking Tests
  # ============================================================
  describe 'Metadata Tracking' do
    let(:auth_header) { auth_headers(user)['Authorization'] }

    it 'stores upload metadata in blob' do
      file = create_test_image

      post '/v1/uploads', params: { file: file, target: 'rich-editor' },
           headers: { 'Authorization' => auth_header }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      blob = ActiveStorage::Blob.find_signed(json['data']['signed_id'])
      expect(blob).to be_present
      expect(blob.metadata['target']).to eq('rich-editor')
      expect(blob.metadata['uploaded_by']).to eq(user.id)
      expect(blob.metadata['uploaded_at']).to be_present
    end
  end
end
