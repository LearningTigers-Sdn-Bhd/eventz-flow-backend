require 'rails_helper'

RSpec.describe PurgeUnattachedBlobsJob, type: :job do
  include ActiveJob::TestHelper

  def create_blob(filename)
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('bytes'),
      filename: filename,
      content_type: 'image/jpeg'
    )
  end

  it 'purges old unattached blobs and spares attached and recent ones' do
    old_unattached = create_blob('old.jpg')
    old_unattached.update_column(:created_at, 3.days.ago)

    recent_unattached = create_blob('recent.jpg')

    event = create(:event)
    ticket_type = create(:ticket_type, event: event)
    ticket = create(:ticket, event: event, ticket_type: ticket_type)
    old_attached = create_blob('attached.jpg')
    ticket.registration_documents.attach(old_attached)
    old_attached.update_column(:created_at, 3.days.ago)

    expect { described_class.perform_now }
      .to have_enqueued_job(ActiveStorage::PurgeJob).exactly(:once)

    enqueued_blob_gid = enqueued_jobs.last['arguments'].first['_aj_globalid']
    expect(enqueued_blob_gid).to include("/#{old_unattached.id}")
    expect { recent_unattached.reload }.not_to raise_error
  end
end
