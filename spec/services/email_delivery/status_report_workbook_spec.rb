require 'rails_helper'

RSpec.describe EmailDelivery::StatusReportWorkbook do
  let(:event) { create(:event, title: 'Big Expo') }

  def workbook(deliveries)
    file = Tempfile.new(['status', '.xlsx'], binmode: true)
    file.write(described_class.new(event, deliveries: deliveries).call)
    file.flush
    Roo::Excelx.new(file.path)
  ensure
    file&.close!
  end

  def rows(book, name)
    book.sheet(name).parse
  end

  let(:ticket) { create(:ticket, event: event, attendee_name: 'Aini', attendee_phone: '0123456789') }
  let(:bounced) do
    create(:email_delivery, :sent, status: 'bounced', recipient: 'aini@example.con', related: ticket, event_id: event.id)
  end
  let(:delivered) { create(:email_delivery, :delivered, event_id: event.id) }
  let(:sent) { create(:email_delivery, :sent, event_id: event.id) }

  it 'has a summary, the full list, then a sheet per outcome that has emails' do
    book = workbook([bounced, delivered, sent])

    expect(book.sheets).to eq(['Summary', 'All Emails', 'Needs Attention', 'Sent', 'Delivered'])
  end

  it 'lists every email on All Emails and only the matching ones on each outcome sheet' do
    book = workbook([bounced, delivered, sent])

    expect(rows(book, 'All Emails').count { |r| r.include?('Ticket confirmation') }).to eq(3)
    expect(rows(book, 'Needs Attention').count { |r| r.include?('Ticket confirmation') }).to eq(1)
    expect(rows(book, 'Delivered').count { |r| r.include?('Ticket confirmation') }).to eq(1)
  end

  it 'writes problems in plain words with the attendee phone' do
    row = rows(workbook([bounced]), 'Needs Attention').find { |r| r.include?('Aini') }

    expect(row).to include('Aini', 'aini@example.con', '0123456789', 'Ticket confirmation', 'Bounced',
                           'The mailbox rejected the email', 'Correct the email address, then resend')
  end

  it 'summarises each outcome with its share' do
    summary = rows(workbook([bounced, delivered, sent, create(:email_delivery, :sent, event_id: event.id)]), 'Summary')

    expect(summary).to include(['Needs attention', 1, 0.25], ['Sent', 2, 0.5], ['Delivered', 1, 0.25], ['Total', 4, 1])
  end

  it 'never evaluates attendee text as a formula' do
    ticket.update!(attendee_name: '=cmd|calc')

    expect(rows(workbook([bounced]), 'All Emails').flatten).to include('=cmd|calc')
  end

  it 'still gives a Needs Attention sheet when nothing went wrong' do
    book = workbook([delivered])

    expect(rows(book, 'Needs Attention').flatten.compact.join(' ')).to include('No problem emails')
  end
end
