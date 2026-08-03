# spec/factories/certificate_templates.rb

FactoryBot.define do
  factory :certificate_template do
    event
    status { :draft }
    orientation { 'landscape' }
    canvas_width { 1123 }
    canvas_height { 794 }
    fields do
      [
        {
          'id' => 'f_name',
          'type' => 'attendee_name',
          'label' => 'Attendee Name',
          'x' => 200,
          'y' => 350,
          'width' => 700,
          'height' => 100,
          'font_size' => 48,
          'font_style' => 'bold',
          'color' => '#1A1A1A',
          'align' => 'center'
        }
      ]
    end

    trait :with_background do
      after(:build) do |template|
        template.background_image.attach(
          io: Rails.root.join('spec/fixtures/files/certificate_background.png').open,
          filename: 'certificate_background.png',
          content_type: 'image/png'
        )
      end
    end

    trait :ready do
      with_background
      status { :ready }
    end
  end
end
