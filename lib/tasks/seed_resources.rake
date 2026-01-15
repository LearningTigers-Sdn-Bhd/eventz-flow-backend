# lib/tasks/seed_resources.rake
namespace :db do
  namespace :seed do
    desc "Seed only resources data (topics, categories, media types, write permissions, and professional posts)"
    task resources: :environment do
      puts "\n" + "=" * 80
      puts "RESOURCE CMS SEEDING"
      puts "=" * 80

      # A. Resource Topics
      puts "\n--- Seeding Resource Topics ---"
      topics_data = [
        { name: "Event Management", icon: "Calendar" },
        { name: "AI at work", icon: "Bot" },
        { name: "Business Matching", icon: "Briefcase" },
        { name: "Project Planning", icon: "ListChecks" }
      ]
      topics_data.each do |topic_data|
        ResourceTopic.find_or_create_by!(name: topic_data[:name]) do |t|
          t.slug = topic_data[:name].parameterize
          t.logo = topic_data[:icon]
        end
      end
      puts "✓ Resource Topics: #{ResourceTopic.count}"

      # B. Resource Categories
      puts "\n--- Seeding Resource Categories ---"
      categories_data = ["Corporate", "Wedding", "Exhibition", "Celebration"]
      categories_data.each do |category_name|
        ResourceCategory.find_or_create_by!(name: category_name) do |c|
          c.slug = category_name.parameterize
        end
      end
      puts "✓ Resource Categories: #{ResourceCategory.count}"

      # C. Resource Media Types
      puts "\n--- Seeding Resource Media Types ---"
      media_types_data = ["Audiobook", "eBook", "Article", "Report", "Webinar", "Video"]
      media_types_data.each do |media_type_name|
        ResourceMediaType.find_or_create_by!(name: media_type_name) do |mt|
          mt.slug = media_type_name.parameterize
        end
      end
      puts "✓ Resource Media Types: #{ResourceMediaType.count}"

      # D. Grant write permissions to all org_owner accounts
      puts "\n--- Granting Write Permissions to Org Owners ---"
      org_owners = User.where(role: :org_owner)
      org_owners.each do |owner|
        ResourceWritePermission.find_or_create_by!(user: owner) do |permission|
          permission.is_official = true
        end
        puts "  → Granted permission to #{owner.email}"
      end
      puts "✓ Total Write Permissions: #{ResourceWritePermission.count}"

      # E. Find the author (s@s.com)
      author = User.find_by(email: 's@s.com')
      if author.nil?
        puts "\n⚠️  ERROR: User with email 's@s.com' not found. Cannot create posts."
        puts "   Please ensure this user exists before running this seed."
        exit(1)
      end

      # F. Create professional blog posts
      puts "\n--- Creating Professional Blog Posts ---"

      # Get references for relationships
      topic_event_management = ResourceTopic.find_by(name: "Event Management")
      topic_ai_at_work = ResourceTopic.find_by(name: "AI at work")
      topic_business_matching = ResourceTopic.find_by(name: "Business Matching")

      category_corporate = ResourceCategory.find_by(name: "Corporate")
      category_exhibition = ResourceCategory.find_by(name: "Exhibition")
      category_celebration = ResourceCategory.find_by(name: "Celebration")

      media_type_article = ResourceMediaType.find_by(name: "Article")

      # ============================================================================
      # PRIORITY 1 POSTS
      # ============================================================================

      # Helper method to attach images from public/post directory
      def attach_header_image(resource, filename)
        file_path = Rails.root.join('public', 'post', filename)
        if File.exist?(file_path)
          # Map file extensions to correct MIME types
          ext = File.extname(filename).delete('.').downcase
          content_type_map = {
            'jpg' => 'image/jpeg',
            'jpeg' => 'image/jpeg',
            'png' => 'image/png',
            'gif' => 'image/gif',
            'webp' => 'image/webp'
          }
          content_type = content_type_map[ext] || "image/#{ext}"

          begin
            # Remove existing attachment if present
            resource.header_img.purge if resource.header_img.attached?

            resource.header_img.attach(
              io: File.open(file_path),
              filename: filename,
              content_type: content_type
            )

            # Save the resource to persist the attachment and run validations
            resource.save!
            puts "    ✓ Attached image: #{filename} (#{content_type})"
          rescue => e
            puts "    ❌ Error attaching #{filename}: #{e.message}"
            if resource.errors.any?
              puts "       Validation errors: #{resource.errors.full_messages.join(', ')}"
            end
            puts "       #{e.backtrace.first(3).join("\n       ")}"
          end
        else
          puts "    ⚠️  Image not found: #{file_path}"
        end
      end

      # Post 1: About EventzFlow
      post_1_title = "EventzFlow: Your All-in-One Event Management Platform"
      post_1_content = <<~HTML
        <h2>Introduction</h2>
        <p>In today's fast-paced event industry, managing every aspect of an event—from registration to post-event analytics—can be overwhelming. EventzFlow emerges as a comprehensive solution designed to streamline every stage of event planning and execution. With cutting-edge AI-powered features and an intuitive interface, EventzFlow transforms complex event management into a seamless experience, allowing organizers to focus on creating memorable experiences rather than wrestling with logistics.</p>

        <h2>Understanding EventzFlow: The 5Ws</h2>
        <p><strong>Who</strong> benefits from EventzFlow? Event organizers, exhibition managers, corporate event planners, wedding coordinators, and venue managers all find value in this platform. <strong>What</strong> is EventzFlow? It's an end-to-end event management ecosystem that combines ticketing, check-in, badge printing, business matching, lucky draws, exhibitor management, and real-time analytics in one unified platform. <strong>When</strong> should you use EventzFlow? From the initial planning stages through post-event analysis, EventzFlow supports your entire event lifecycle. <strong>Where</strong> does it work? As a cloud-based solution with mobile-responsive design, EventzFlow operates seamlessly across conferences, exhibitions, corporate gatherings, weddings, and celebrations of any scale. <strong>Why</strong> choose EventzFlow? Because it eliminates the need for multiple disconnected tools, reduces operational complexity, and leverages AI to provide insights that help you make data-driven decisions and improve attendee engagement.</p>

        <h2>Comprehensive Event Management in One Platform</h2>
        <p>EventzFlow consolidates multiple event management functions into a single, cohesive platform. Gone are the days of juggling separate systems for ticketing, registration, check-in, and analytics. With EventzFlow, you get QR code-based registration, instant badge printing, real-time attendance tracking, and customizable ticket types—all working together seamlessly. This integration means fewer technical headaches, reduced training time for your team, and a smoother experience for your attendees.</p>

        <h2>AI-Powered Intelligence for Better Events</h2>
        <p>What sets EventzFlow apart is its AI-powered capabilities that go beyond basic event management. The platform offers intelligent audience profiling, automated business matching between attendees and exhibitors, and predictive analytics that help you understand attendee behavior patterns. With visitor booth tracking and engagement metrics, you can measure what matters and optimize your events based on real data. The AI components work quietly in the background, automatically matching the right people for networking opportunities and providing insights that would take hours to uncover manually.</p>

        <h2>Enhanced Attendee Experience</h2>
        <p>From an attendee's perspective, EventzFlow creates a frictionless event experience. WhatsApp bot registration allows attendees to sign up without downloading apps or filling out lengthy forms. QR codes provide contactless check-in, eliminating long queues at the entrance. The appless web portal means attendees can access event information, book meetings, and participate in lucky draws directly from their mobile browsers. Business matching features enable meaningful connections by allowing attendees to schedule meetings with exhibitors and speakers. Every feature is designed with the end-user in mind, ensuring high satisfaction and engagement rates.</p>

        <h2>Conclusion</h2>
        <p>EventzFlow represents the future of event management—a platform that brings together all the tools you need while leveraging AI to make smarter decisions. Whether you're organizing a small corporate gathering or a large-scale exhibition, EventzFlow scales to meet your needs. By reducing complexity, improving attendee experiences, and providing actionable insights, EventzFlow empowers event organizers to create exceptional events with confidence. Ready to transform how you manage events? Discover what EventzFlow can do for your next event.</p>
      HTML

      post_1 = Resource.find_or_initialize_by(slug: post_1_title.parameterize)
      if post_1.new_record?
        post_1.assign_attributes(
          title: post_1_title,
          article: post_1_content,
          meta_description: "Discover EventzFlow, the all-in-one event management platform with AI-powered features for ticketing, check-in, business matching, and real-time analytics.",
          user: author,
          resource_topic: topic_event_management,
          resource_category: category_corporate,
          resource_media_type: media_type_article,
          status: :published,
          published_at: Time.current,
          is_gated: false,
          is_official: true,
          priority: 1,
          view_counts: 0
        )
        post_1.save!
        attach_header_image(post_1, "Eventzflow.jpg")
        puts "  ✓ Created: #{post_1_title}"
      else
        # Reattach image if missing (useful after db:reset)
        unless post_1.header_img.attached?
          attach_header_image(post_1, "Eventzflow.jpg")
        end
        puts "  → Already exists: #{post_1_title}"
      end

      # Post 2: Event Planning Made Simple
      post_2_title = "Event Planning Made Simple: A Modern Approach to Seamless Events"
      post_2_content = <<~HTML
        <h2>Introduction</h2>
        <p>Event planning has evolved dramatically in recent years, yet many organizers still struggle with fragmented tools, manual processes, and disconnected data. The complexity of coordinating vendors, managing registrations, tracking attendance, and measuring success can quickly become overwhelming. Modern event planning demands a fresh approach—one that embraces technology to simplify workflows, reduce stress, and deliver exceptional experiences. This guide explores how contemporary event management strategies can transform your planning process from chaotic to streamlined.</p>

        <h2>The Fundamentals: The 5Ws of Modern Event Planning</h2>
        <p><strong>Who</strong> needs simplified event planning? Professional event organizers, corporate meeting planners, marketing teams, venue managers, and anyone responsible for creating successful gatherings. <strong>What</strong> is modern event planning? It's the practice of leveraging integrated technology platforms to manage the entire event lifecycle—from initial concept through post-event analysis—in a coordinated, data-driven manner. <strong>When</strong> should you adopt modern planning methods? Ideally from your very next event, but especially when you're experiencing inefficiencies, data silos, or attendee satisfaction issues. <strong>Where</strong> does this approach apply? Whether you're planning intimate board meetings, large conferences, trade shows, corporate celebrations, or hybrid events, modern planning principles scale to fit any event type or size. <strong>Why</strong> make the shift? Because simplified planning reduces costs, saves time, minimizes errors, improves attendee experiences, and provides measurable ROI through better data and insights.</p>

        <h2>Eliminating Tool Fragmentation</h2>
        <p>One of the biggest challenges in traditional event planning is managing multiple disconnected systems—separate platforms for ticketing, registration, email campaigns, check-in, analytics, and more. Each tool requires its own login, learning curve, and data export process. Modern event planning consolidates these functions into unified platforms that allow seamless data flow between modules. When your registration system talks to your check-in system, which connects to your analytics dashboard, you eliminate manual data entry, reduce errors, and gain real-time visibility into your event's performance. This integration doesn't just save time; it enables you to make informed decisions on the fly and respond quickly to issues as they arise.</p>

        <h2>Automating Repetitive Tasks</h2>
        <p>Event planning involves countless repetitive tasks: sending confirmation emails, generating badges, updating attendee lists, collecting payments, and more. Modern platforms automate these workflows, freeing your team to focus on strategic activities that actually impact event success. Automated registration confirmations go out instantly, QR codes are generated automatically, payment reminders are sent on schedule, and attendance data updates in real-time without manual intervention. This automation not only saves hundreds of hours but also ensures consistency and accuracy that manual processes can't match. Your team can shift from being task executors to experience designers.</p>

        <h2>Creating Engaging Attendee Experiences</h2>
        <p>Simplified event planning isn't just about making life easier for organizers—it directly improves the attendee experience. When your systems work smoothly behind the scenes, attendees enjoy faster registration, shorter check-in lines, personalized communications, and seamless access to event features. Modern planning approaches enable features like WhatsApp registration, mobile-friendly portals, instant badge printing, and business matching that attendees appreciate. By removing friction from the attendee journey, you increase satisfaction, engagement, and the likelihood that participants will attend future events. Happy attendees become your best marketing channel.</p>

        <h2>Data-Driven Decision Making</h2>
        <p>Perhaps the most transformative aspect of modern event planning is the shift from gut-feel decisions to data-driven strategies. Integrated platforms provide comprehensive analytics on registration patterns, attendance rates, engagement metrics, popular sessions, and attendee demographics. This data helps you understand what's working and what isn't—not just after the event, but in real-time during the event. You can identify which marketing channels deliver the best ROI, which sessions need more capacity, and which sponsors are getting the most engagement. Over time, these insights help you continuously improve your events, justify budgets with concrete metrics, and demonstrate clear value to stakeholders.</p>

        <h2>Conclusion</h2>
        <p>Event planning doesn't have to be complicated. By embracing modern approaches that prioritize integration, automation, and data, you can dramatically simplify your workflow while simultaneously improving event outcomes. The key is choosing tools and platforms that work together seamlessly, eliminate manual processes, and provide the insights you need to make smart decisions. Whether you're planning your first event or your hundredth, simplifying your approach with contemporary event management strategies will save you time, reduce stress, and help you create events that truly resonate with your audience. The future of event planning is here—and it's simpler than you think.</p>
      HTML

      post_2 = Resource.find_or_initialize_by(slug: post_2_title.parameterize)
      if post_2.new_record?
        post_2.assign_attributes(
          title: post_2_title,
          article: post_2_content,
          meta_description: "Learn how modern event planning strategies simplify workflows, reduce complexity, and help you create seamless events with integrated technology.",
          user: author,
          resource_topic: topic_event_management,
          resource_category: category_corporate,
          resource_media_type: media_type_article,
          status: :published,
          published_at: Time.current,
          is_gated: false,
          is_official: true,
          priority: 1,
          view_counts: 0
        )
        post_2.save!
        attach_header_image(post_2, "Event-Planning.jpg")
        puts "  ✓ Created: #{post_2_title}"
      else
        unless post_2.header_img.attached?
          attach_header_image(post_2, "Event-Planning.jpg")
        end
        puts "  → Already exists: #{post_2_title}"
      end

      # ============================================================================
      # PRIORITY 2 POSTS
      # ============================================================================

      # Post 3: Lucky Draw for Events
      post_3_title = "Lucky Draw for Events: Boost Engagement with Interactive Giveaways"
      post_3_content = <<~HTML
        <h2>Introduction</h2>
        <p>Every event organizer knows the challenge: keeping attendees engaged throughout your event. Lucky draws and giveaways have long been proven tactics for maintaining energy, encouraging participation, and creating memorable moments. However, traditional manual lucky draw methods—pulling names from a hat or using basic random number generators—lack the visual excitement and professional polish that modern events demand. Today's digital lucky draw systems transform simple giveaways into spectacular, branded experiences that captivate audiences and amplify engagement.</p>

        <h2>Understanding Lucky Draws: The 5Ws</h2>
        <p><strong>Who</strong> benefits from lucky draw systems? Event organizers across all industries—from corporate conferences and product launches to wedding receptions and charity galas—use lucky draws to boost participation and excitement. <strong>What</strong> is a digital lucky draw system? It's an interactive platform that randomly selects winners from your attendee pool using engaging visual animations like spinning wheels, slot machines, or mystery boxes, while managing multiple prizes, sessions, and participant pools. <strong>When</strong> should you incorporate lucky draws? Use them during natural lulls in your event schedule, as session transitions, during meals, or as grand finale attractions to end on a high note. <strong>Where</strong> does it work? Digital lucky draw systems function on any display—from massive LED screens at conferences to tablets at intimate gatherings—and can pull participants from your registered attendees or walk-in visitors. <strong>Why</strong> implement lucky draws? Because they create anticipation, reward attendance, encourage early arrival, increase booth visits, extend engagement throughout your event, and generate social media buzz as winners share their excitement.</p>

        <h2>Creating Memorable Visual Experiences</h2>
        <p>Modern lucky draw systems go far beyond simply announcing a winner. They create spectacle through stunning visual animations that build suspense and excitement. Choose from multiple draw styles—spinning wheels that gradually slow to land on the winner, slot machine animations that cycle through names before stopping, or mystery box reveals that heighten anticipation. Customize themes to match your event branding with options like wireframe technical styles for tech conferences, colorful vibrant designs for consumer events, or playful cartoon themes for family-friendly gatherings. Add your logo, custom backgrounds, and brand colors to ensure the lucky draw feels like an integrated part of your event rather than a generic add-on. These visual elements transform a simple giveaway into entertainment that attendees will remember and talk about long after the event ends.</p>

        <h2>Flexible Prize and Session Management</h2>
        <p>Professional lucky draw systems offer sophisticated management capabilities that manual methods simply can't match. Set up multiple prizes with specific winner counts for each—perhaps three winners for a premium prize and ten winners for consolation gifts. Run separate draw sessions throughout your event for different purposes or audience segments: a morning session for early birds, a lunch session for networking encouragement, and a grand finale session for the biggest prizes. Control participant pools by drawing from all registered attendees, only checked-in visitors, or specific ticket types. Exclude previous winners automatically to ensure fair distribution, or allow repeat winners if your prize pool is large. This flexibility means you can design lucky draw strategies that align with your specific engagement goals rather than settling for one-size-fits-all approaches.</p>

        <h2>Encouraging Attendance and Participation</h2>
        <p>Lucky draws serve as powerful incentives that influence attendee behavior in positive ways. Announcing that only registered attendees are eligible encourages advance registration rather than walk-ins. Requiring check-in to participate motivates punctual arrival and reduces no-show rates. Running draws at specific times ensures audiences stay engaged throughout multi-day events rather than leaving early. Linking draw eligibility to booth visits or session attendance drives traffic to exhibitors and increases participation in your programming. The psychological appeal of potentially winning prizes creates an emotional connection to your event that purely informational content cannot match. Attendees don't just come to learn; they come to potentially win, which fundamentally changes their engagement mindset.</p>

        <h2>Building Social Proof and Excitement</h2>
        <p>The moments when winners are announced generate organic social media content that money can't buy. Winners naturally share their excitement, post photos of their prizes, and tag your event in their updates. The visual spectacle of the draw itself is shareable—attendees record spinning wheels and slot machine animations, creating authentic video content showcasing event energy. This user-generated content serves as social proof for future events, showing prospective attendees that your events are fun, rewarding, and worth attending. The excitement is contagious; when one person wins, the entire audience feels the possibility that they could be next, maintaining engagement even for those who don't win.</p>

        <h2>Conclusion</h2>
        <p>Lucky draws have evolved from simple raffle tickets to sophisticated engagement tools that create memorable experiences, influence attendee behavior, and generate valuable social proof. By implementing a professional digital lucky draw system with stunning visuals, flexible management options, and seamless integration with your registration data, you transform simple giveaways into strategic engagement drivers. Whether you're looking to increase attendance, extend engagement, drive booth traffic, or simply create moments of joy, lucky draws deliver measurable results while adding an element of fun that attendees genuinely appreciate. Make your next event more engaging, more memorable, and more successful with a properly executed lucky draw strategy.</p>
      HTML

      post_3 = Resource.find_or_initialize_by(slug: post_3_title.parameterize)
      if post_3.new_record?
        post_3.assign_attributes(
          title: post_3_title,
          article: post_3_content,
          meta_description: "Discover how interactive lucky draws boost event engagement with multiple draw styles, custom themes, and flexible prize management.",
          user: author,
          resource_topic: topic_event_management,
          resource_category: category_celebration,
          resource_media_type: media_type_article,
          status: :published,
          published_at: Time.current,
          is_gated: false,
          is_official: true,
          priority: 2,
          view_counts: 0
        )
        post_3.save!
        attach_header_image(post_3, "Lucky-Draw.png")
        puts "  ✓ Created: #{post_3_title}"
      else
        unless post_3.header_img.attached?
          attach_header_image(post_3, "Lucky-Draw.png")
        end
        puts "  → Already exists: #{post_3_title}"
      end

      # Post 4: Event Exhibition Management
      post_4_title = "Event Exhibition Management: Empower Exhibitors with Self-Service Portals"
      post_4_content = <<~HTML
        <h2>Introduction</h2>
        <p>Exhibition events bring unique management challenges: coordinating dozens or hundreds of exhibitors, ensuring each booth is properly set up, managing exhibitor teams, and tracking visitor engagement across the venue. Traditional exhibition management often involves endless emails, spreadsheet chaos, and frustrated exhibitors who can't get timely information. Modern exhibition management systems flip this model by empowering exhibitors with self-service portals where they can manage their own booth details, add team members, and track leads—reducing your workload while improving exhibitor satisfaction.</p>

        <h2>The Exhibitor Management Essentials: The 5Ws</h2>
        <p><strong>Who</strong> benefits from exhibitor management systems? Trade show organizers, exhibition venue managers, B2B event planners, expo coordinators, and anyone managing events with vendor or exhibitor components. <strong>What</strong> is an exhibitor management portal? It's a dedicated platform where each exhibitor gets their own dashboard to manage booth information, upload logos and materials, add team members, view visitor analytics, and track lead capture—all without requiring organizer intervention. <strong>When</strong> should exhibitors access these portals? From the moment they're confirmed for your event through post-event analytics review, providing continuous value before, during, and after the exhibition. <strong>Where</strong> does this apply? Any event format featuring exhibitors, vendors, sponsors with booths, poster sessions, or demo areas benefits from giving participants self-management capabilities. <strong>Why</strong> implement exhibitor portals? Because they dramatically reduce organizer workload, eliminate back-and-forth communication, give exhibitors control and transparency, improve data accuracy, and enable exhibitors to maximize their event ROI through better lead management.</p>

        <h2>Self-Service Reduces Organizer Burden</h2>
        <p>Without exhibitor portals, organizers become bottlenecks for every update. Exhibitors email requesting booth detail changes, team member additions, or lead reports, and your staff manually processes each request. This creates delays, potential errors, and enormous time consumption as your event scales. Exhibitor portals eliminate this bottleneck by allowing exhibitors to make updates directly. They can modify their booth descriptions, upload new logos, add or remove team members, and download their lead lists—all without sending a single email to your team. This shift from manual coordination to self-service scales infinitely; managing 100 exhibitors takes barely more effort than managing 10. Your team shifts from data entry and status updates to strategic support that actually improves event quality.</p>

        <h2>Enhanced Exhibitor Experience and Control</h2>
        <p>Exhibitors invest significant resources in your event—booth fees, travel costs, staff time, and marketing materials. They deserve transparency and control over their exhibition experience. Exhibitor portals provide exactly that: real-time visibility into their booth status, team roster, and visitor engagement metrics. Exhibitors can log in anytime to see how many visitors have checked into their booth, which sessions are driving traffic, and how their presence compares to previous events. This transparency builds trust and demonstrates that you value their investment. When exhibitors feel empowered rather than dependent on organizers for basic information, their satisfaction increases, making them more likely to return for future events and recommend your exhibitions to peers.</p>

        <h2>Streamlined Team Management</h2>
        <p>Most exhibitors bring teams to manage their booths—sales representatives, product specialists, technical experts, and support staff. Coordinating team member credentials, badge printing, and access permissions traditionally requires complex coordination between exhibitors and organizers. Exhibitor portals simplify this by allowing booth owners to add their own team members directly into the system. The exhibitor enters team member names, emails, and roles; the system automatically generates credentials; and team members receive their QR codes for check-in. Organizers simply approve the additions rather than manually creating each registration. This self-service approach is faster, more accurate (exhibitors know their team better than organizers do), and scales effortlessly regardless of team sizes.</p>

        <h2>Visitor Tracking and Lead Management</h2>
        <p>The primary reason exhibitors participate in your event is lead generation. Exhibitor portals with integrated visitor tracking transform how exhibitors capture and manage leads. When visitors scan QR codes at booths, that data flows immediately to the exhibitor's dashboard. Exhibitors can see in real-time who visited their booth, when they visited, how long they stayed, and what materials they viewed. After the event, exhibitors download complete visitor reports with contact information, visit timestamps, and engagement details—eliminating the manual business card collection and transcription that leads to lost opportunities. This capability directly impacts exhibitor ROI, making it easier to justify their participation and increasing the likelihood of renewal for your next event.</p>

        <h2>Conclusion</h2>
        <p>Modern exhibition management succeeds by empowering exhibitors rather than controlling every detail centrally. Self-service portals reduce organizer workload, improve exhibitor satisfaction, streamline team management, and enable effective lead capture—all while providing transparency and control that exhibitors genuinely value. By implementing an exhibitor management system, you transform your role from reactive coordinator to strategic partner, spending less time on administrative tasks and more time creating exceptional exhibition experiences. Whether you're managing a small trade show or a massive international expo, exhibitor portals scale to meet your needs while delivering measurable value to everyone involved. Give your exhibitors the tools they deserve, and watch your exhibitions thrive.</p>
      HTML

      post_4 = Resource.find_or_initialize_by(slug: post_4_title.parameterize)
      if post_4.new_record?
        post_4.assign_attributes(
          title: post_4_title,
          article: post_4_content,
          meta_description: "Learn how exhibitor management portals empower booth owners with self-service tools for team management, lead tracking, and visitor engagement.",
          user: author,
          resource_topic: topic_event_management,
          resource_category: category_exhibition,
          resource_media_type: media_type_article,
          status: :published,
          published_at: Time.current,
          is_gated: false,
          is_official: true,
          priority: 2,
          view_counts: 0
        )
        post_4.save!
        attach_header_image(post_4, "Event-Exhibition.jpg")
        puts "  ✓ Created: #{post_4_title}"
      else
        unless post_4.header_img.attached?
          attach_header_image(post_4, "Event-Exhibition.jpg")
        end
        puts "  → Already exists: #{post_4_title}"
      end

      # Post 5: Event Ticketing & Registration
      post_5_title = "Event Ticketing & Registration: Streamline Sign-Ups with Modern Tools"
      post_5_content = <<~HTML
        <h2>Introduction</h2>
        <p>The registration experience sets the tone for your entire event. Cumbersome forms, confusing ticket options, and slow confirmation processes frustrate attendees before they even arrive. Meanwhile, organizers struggle with disparate systems for ticketing, payment processing, attendee data collection, and QR code generation. Modern event registration platforms consolidate these functions into seamless experiences that make signing up effortless for attendees while giving organizers comprehensive control and rich data. The result: higher conversion rates, better attendee data, and smoother event execution.</p>

        <h2>Registration Fundamentals: The 5Ws</h2>
        <p><strong>Who</strong> needs modern registration systems? Any event requiring attendee sign-up benefits—from conferences and workshops to concerts, galas, webinars, and corporate functions. <strong>What</strong> constitutes modern event registration? Integrated platforms that combine customizable web forms, multiple ticket types with flexible pricing, automated confirmation emails, QR code generation, payment processing, bulk import capabilities, and custom field collection—all working together seamlessly. <strong>When</strong> should registration open? Typically 2-6 months before your event for major conferences, adjusted based on your audience's planning timelines and the urgency you want to create. <strong>Where</strong> should attendees register? Provide multiple channels: your event website, social media links, email campaigns, and for modern platforms, even WhatsApp registration options that meet attendees where they already communicate. <strong>Why</strong> invest in sophisticated registration? Because it directly impacts attendance numbers, revenue collection, data quality, operational efficiency, and the crucial first impression your event makes on potential attendees.</p>

        <h2>Flexible Ticket Types and Pricing</h2>
        <p>One-size-fits-all ticketing limits your revenue potential and fails to serve diverse audience segments. Modern registration systems enable sophisticated ticket type strategies that maximize attendance and revenue. Create Early Bird tickets with time-limited discounted pricing to encourage early commitment and improve cash flow. Offer VIP packages with premium pricing and exclusive benefits for attendees willing to pay more. Establish Student or Group discounts to expand accessibility. Set up Day Passes versus Full Conference options for multi-day events. Configure each ticket type with specific quantities, maximum per-order limits, and availability windows. This flexibility allows you to implement dynamic pricing strategies that fill your venue while optimizing revenue—Early Bird tickets create urgency, Standard pricing captures the majority, and Last-Minute options fill remaining capacity.</p>

        <h2>Custom Fields and Data Collection</h2>
        <p>Generic registration forms collect names and emails but miss the opportunity to gather insights that improve your event. Custom fields enable targeted data collection aligned with your specific needs. Add dietary preference questions to inform catering. Include industry and job title fields to understand your audience composition and tailor content. Ask about session interests to predict attendance distribution and right-size room capacities. Collect t-shirt sizes for branded merchandise. Request accessibility needs to ensure inclusive experiences. The key is balance—collect enough data to enhance your event and personalization, but not so much that form length depresses completion rates. Each custom field should have a clear purpose and actionable application.</p>

        <h2>Frictionless Registration Channels</h2>
        <p>Traditional registration requires attendees to visit your website, fill out forms, and complete checkout—multiple steps where drop-off can occur. Modern platforms reduce friction by offering alternative registration channels that meet attendees where they are. WhatsApp bot registration allows attendees to sign up through natural conversation without leaving their messaging app—perfect for audiences already using WhatsApp extensively. QR code registration enables instant sign-up by scanning codes on posters, flyers, or digital ads. Bulk import capabilities let corporate clients or group organizers register entire teams via spreadsheet uploads rather than individual form submissions. By providing multiple pathways to registration, you reduce barriers and increase conversion rates across different audience preferences and use cases.</p>

        <h2>Automated Confirmation and Communication</h2>
        <p>The moments immediately after registration are critical for setting expectations and maintaining momentum. Automated systems handle this perfectly while scaling effortlessly. The instant someone completes registration, they receive a confirmation email with their ticket details, unique QR code, event information, and calendar invite—no manual work required. As your event approaches, automated reminder emails keep it top-of-mind and reduce no-shows. If attendees forget their tickets, self-service retrieval links let them resend QR codes without contacting your team. For paid tickets, payment confirmation and receipt delivery happen automatically. This automation ensures consistent, professional communication with every attendee while freeing your team from repetitive email tasks and allowing you to focus on event content and experience design.</p>

        <h2>Conclusion</h2>
        <p>Event registration is far more than a necessary administrative task—it's your first opportunity to impress attendees and set the stage for a successful event. By implementing modern registration platforms that offer flexible ticket types, custom data collection, multiple registration channels, and automated communication, you simultaneously improve the attendee experience and gain operational efficiencies. Higher conversion rates mean more attendees. Better data means smarter event decisions. Automated processes mean less work for your team. Whether you're planning an intimate workshop or a massive conference, investing in sophisticated registration capabilities pays dividends throughout your event lifecycle. Make registration seamless, and everything that follows becomes easier.</p>
      HTML

      post_5 = Resource.find_or_initialize_by(slug: post_5_title.parameterize)
      if post_5.new_record?
        post_5.assign_attributes(
          title: post_5_title,
          article: post_5_content,
          meta_description: "Discover how modern event registration systems streamline sign-ups with flexible ticket types, custom fields, and multiple registration channels.",
          user: author,
          resource_topic: topic_event_management,
          resource_category: category_corporate,
          resource_media_type: media_type_article,
          status: :published,
          published_at: Time.current,
          is_gated: false,
          is_official: true,
          priority: 2,
          view_counts: 0
        )
        post_5.save!
        attach_header_image(post_5, "Event-Ticket.png")
        puts "  ✓ Created: #{post_5_title}"
      else
        unless post_5.header_img.attached?
          attach_header_image(post_5, "Event-Ticket.png")
        end
        puts "  → Already exists: #{post_5_title}"
      end

      # Post 6: WhatsApp Automation in Event Management
      post_6_title = "WhatsApp Automation in Event Management: Meet Attendees Where They Are"
      post_6_content = <<~HTML
        <h2>Introduction</h2>
        <p>With over 2 billion users worldwide, WhatsApp has become the primary communication channel for billions of people. Yet most event registration systems force attendees to leave WhatsApp, visit external websites, fill out forms, and wait for email confirmations—introducing friction at every step. WhatsApp automation for events eliminates these barriers by allowing attendees to register, receive confirmations, get reminders, and access event information without ever leaving their favorite messaging app. This approach dramatically improves conversion rates, especially for audiences where WhatsApp is deeply embedded in daily communication patterns.</p>

        <h2>WhatsApp Automation Explained: The 5Ws</h2>
        <p><strong>Who</strong> benefits most from WhatsApp automation? Events targeting audiences in regions where WhatsApp dominates (Southeast Asia, Latin America, Middle East, Africa), mobile-first users, older demographics less comfortable with app downloads, and any event seeking to reduce registration friction. <strong>What</strong> does WhatsApp event automation include? Conversational registration flows where attendees provide information through natural chat, automated confirmation messages with ticket details and QR codes, reminder messages as events approach, check-in notifications, and post-event follow-ups—all delivered through WhatsApp Business API integrations. <strong>When</strong> should attendees interact with the bot? From their first awareness of your event through post-event surveys, creating a continuous communication channel that feels personal despite being automated. <strong>Where</strong> does this technology work? Any event can implement WhatsApp automation, but it's particularly powerful for local and regional events, community gatherings, corporate events in WhatsApp-heavy markets, and events with less tech-savvy audiences. <strong>Why</strong> choose WhatsApp over traditional methods? Because it meets attendees in their existing communication environment, supports multiple languages naturally, requires no app downloads, maintains conversation history, enables rich media sharing, and achieves significantly higher open rates (98%) compared to email (20%).</p>

        <h2>Conversational Registration Experience</h2>
        <p>Traditional web forms present all fields at once, creating cognitive overload and intimidating users with long pages. WhatsApp registration transforms this into a natural conversation. The bot greets attendees warmly, asks one question at a time, and adapts based on responses—exactly how a human would conduct registration. "What's your name?" followed by "Great! And your email address?" feels conversational rather than transactional. The bot can provide immediate validation, gently correcting formatting errors and confirming information before moving forward. For ticket selection, the bot presents options with descriptions, allows questions, and processes payments through integrated links. This conversational approach reduces cognitive load, increases completion rates, and creates a friendly first impression that web forms simply cannot match.</p>

        <h2>Instant Confirmations and QR Code Delivery</h2>
        <p>Email confirmation delays—even seconds—create anxiety and uncertainty for new registrants. WhatsApp automation eliminates this gap by delivering instant confirmation messages the moment registration completes. Attendees receive a message confirming their registration, including event details, date, time, location, and most importantly, their unique QR code for check-in—all delivered as an image directly in WhatsApp. This immediate confirmation provides reassurance and ensures attendees have their tickets accessible in the app they use dozens of times daily. No hunting through email folders, no worrying about spam filters, no downloading PDFs. The ticket lives in their WhatsApp conversation, easily retrievable anytime they need it, even offline.</p>

        <h2>Automated Reminders and Updates</h2>
        <p>No-show rates plague events, often reaching 20-30% for free events despite confirmed registrations. WhatsApp automation combats this through timely, personal reminders delivered through a channel attendees actually check. Send a reminder one week before the event with key details. Follow with a message 24 hours prior including parking information or venue maps. Send a final reminder the morning of the event with current weather updates and last-minute logistics. Because WhatsApp messages achieve 98% open rates compared to email's 20%, these reminders actually reach attendees. If event details change—room assignments, schedule adjustments, weather cancellations—WhatsApp provides a direct channel to reach all attendees instantly with updates they'll see within minutes rather than hours.</p>

        <h2>Language Flexibility and Global Reach</h2>
        <p>WhatsApp's global reach means your attendees may speak dozens of different languages. WhatsApp automation platforms can detect language preferences and conduct entire conversations in attendees' native languages. A Spanish-speaking attendee receives registration prompts in Spanish, while an English speaker gets English messages—all from the same bot. This localization happens automatically based on phone number regions or explicit language selection. For international events, conferences with diverse audiences, or events in multilingual regions, this capability dramatically expands your reach and improves accessibility. You're not limited to English-only communication or the expense of manually managing multiple language tracks. The automation handles it seamlessly, making every attendee feel welcomed in their own language.</p>

        <h2>Conclusion</h2>
        <p>WhatsApp automation represents a fundamental shift in event communication—from interrupting attendees with emails they might ignore to meeting them in a space they already inhabit and trust. By enabling conversational registration, instant confirmations, timely reminders, and multilingual support, WhatsApp automation reduces friction, increases conversion rates, improves attendance, and creates more positive attendee experiences. For event organizers, it means higher registration completion, lower no-show rates, and direct communication channels that actually reach attendees. Whether you're organizing community events, corporate functions, or international conferences, WhatsApp automation helps you connect with attendees in the way they prefer to communicate. Meet your attendees where they are, and watch your event engagement soar.</p>
      HTML

      post_6 = Resource.find_or_initialize_by(slug: post_6_title.parameterize)
      if post_6.new_record?
        post_6.assign_attributes(
          title: post_6_title,
          article: post_6_content,
          meta_description: "Learn how WhatsApp automation streamlines event registration with conversational flows, instant confirmations, and automated reminders that meet attendees where they are.",
          user: author,
          resource_topic: topic_ai_at_work,
          resource_category: category_corporate,
          resource_media_type: media_type_article,
          status: :published,
          published_at: Time.current,
          is_gated: false,
          is_official: true,
          priority: 2,
          view_counts: 0
        )
        post_6.save!
        attach_header_image(post_6, "Whatsapp-Automation.jpg")
        puts "  ✓ Created: #{post_6_title}"
      else
        unless post_6.header_img.attached?
          attach_header_image(post_6, "Whatsapp-Automation.jpg")
        end
        puts "  → Already exists: #{post_6_title}"
      end

      # Post 7: Business Matching
      post_7_title = "Business Matching: Facilitate Meaningful Connections at Your Events"
      post_7_content = <<~HTML
        <h2>Introduction</h2>
        <p>Networking is often cited as the primary reason professionals attend conferences and B2B events. Yet traditional networking is chaotic and inefficient—attendees wander exhibit halls hoping to stumble upon relevant connections, miss opportunities because they don't know who else is attending, and leave events having spoken to just a fraction of potentially valuable contacts. Business matching systems transform this random process into strategic, facilitated networking where attendees can identify, schedule, and meet with exactly the right people. The result: higher attendee satisfaction, more business value generated, and events that deliver measurable ROI beyond just educational content.</p>

        <h2>Business Matching Fundamentals: The 5Ws</h2>
        <p><strong>Who</strong> benefits from business matching? B2B conferences, trade shows, investor events, career fairs, startup ecosystems, industry associations, and any event where professional connection-making drives value. Both attendees seeking specific connections and exhibitors/sponsors wanting to maximize lead generation benefit enormously. <strong>What</strong> is business matching? A system that allows attendees to browse profiles of other participants, exhibitors, and speakers; request meetings based on shared interests or complementary needs; view availability calendars; book specific time slots; receive confirmations and reminders; and access meeting reports—all through an integrated platform. <strong>When</strong> do meetings occur? Typically during designated networking periods, breaks, meal times, or dedicated business matching hours built into your event schedule. <strong>Where</strong> does matching happen? The platform works digitally for browsing and booking, while physical meetings occur in designated networking areas, exhibitor booths, private meeting rooms, or informal spaces throughout your venue. <strong>Why</strong> implement business matching? Because it dramatically increases the quality and quantity of connections made, demonstrates clear ROI to attendees and sponsors, differentiates your event from competitors, generates valuable data on connection patterns, and creates stickiness that brings attendees back year after year.</p>

        <h2>Strategic Connection Discovery</h2>
        <p>The fundamental problem business matching solves is discovery—helping attendees find the right people among hundreds or thousands of participants. Without matching systems, attendees rely on name badges glimpsed in passing, speaker bios from sessions attended, or chance encounters at coffee stations. Business matching platforms provide searchable directories where attendees can filter by company, industry, job title, interests, or expertise. Attendees can browse exhibitor profiles to identify which booths merit their time rather than wandering aimlessly. Speakers can be contacted directly for follow-up discussions. Advanced systems even offer AI-powered recommendations that suggest relevant connections based on profile similarities, complementary needs, or matching business objectives. This shift from random encounters to strategic discovery means attendees make better connections, not just more connections.</p>

        <h2>Scheduled Meetings Replace Chaos</h2>
        <p>Even when attendees identify valuable connections, actually meeting them at busy events is challenging. Business matching solves this through structured scheduling. Exhibitors and willing participants set their availability—"I'm available for meetings Tuesday from 2-5 PM"—creating bookable time slots. Attendees browse available times and request meetings that fit their schedules. Once confirmed, both parties receive calendar invites with meeting details: time, location (booth number or meeting room), participant names, and agenda notes. This structure eliminates the "let's try to connect sometime" vagueness that rarely converts to actual meetings. Scheduled meetings happen at defined times in defined places, dramatically increasing follow-through rates and ensuring valuable connections actually occur rather than remaining good intentions.</p>

        <h2>Enhanced Lead Generation for Exhibitors</h2>
        <p>For exhibitors and sponsors, business matching transforms booth traffic from random to qualified. Instead of waiting for whoever happens to walk by, exhibitors receive meeting requests from attendees who specifically want to connect with them—pre-qualified leads with stated interest. Exhibitors can review requester profiles before accepting meetings, prioritizing high-value prospects. The scheduled nature means exhibitors can plan their booth staffing to ensure senior team members are available for important meetings rather than missing opportunities because decision-makers were at lunch. Post-event, exhibitors receive detailed reports showing who they met, when, and any notes captured—creating a structured pipeline for follow-up rather than a pile of business cards with no context. This measurably improves exhibitor ROI, making it easier to justify participation and increasing renewal rates for future events.</p>

        <h2>Data-Driven Networking Insights</h2>
        <p>Business matching platforms generate valuable data that random networking cannot provide. Track which exhibitors receive the most meeting requests, revealing which sponsors deliver the most attendee value. Identify connection patterns between industries, showing unexpected synergies you can highlight in future marketing. Measure meeting completion rates to assess whether you've allocated sufficient networking time and appropriate spaces. Analyze which attendee segments (by seniority, industry, or role) are most actively networking, informing future audience targeting. Survey participants about connection quality and business outcomes generated, demonstrating concrete event value. This data helps you continuously improve networking aspects of your event, justify event value to stakeholders with hard metrics, and market future events with specific networking success stories and statistics.</p>

        <h2>Conclusion</h2>
        <p>Professional events must deliver tangible value beyond educational sessions, and networking represents that value for many attendees. Business matching systems transform networking from chaotic and luck-based to strategic and efficient. By enabling connection discovery, facilitating scheduled meetings, enhancing exhibitor lead generation, and providing valuable networking data, business matching makes your event indispensable for attendees seeking to grow their professional networks and business opportunities. Attendees who make valuable connections at your event will return year after year. Exhibitors who generate quality leads will renew their sponsorships. Business matching isn't just a feature—it's a competitive differentiator that elevates your event from information delivery to business catalyst. Make meaningful connections easier, and watch your event's reputation and value soar.</p>
      HTML

      post_7 = Resource.find_or_initialize_by(slug: post_7_title.parameterize)
      if post_7.new_record?
        post_7.assign_attributes(
          title: post_7_title,
          article: post_7_content,
          meta_description: "Discover how business matching systems facilitate meaningful professional connections through strategic discovery, scheduled meetings, and enhanced lead generation.",
          user: author,
          resource_topic: topic_business_matching,
          resource_category: category_corporate,
          resource_media_type: media_type_article,
          status: :published,
          published_at: Time.current,
          is_gated: false,
          is_official: true,
          priority: 2,
          view_counts: 0
        )
        post_7.save!
        attach_header_image(post_7, "Business-Matching.jpg")
        puts "  ✓ Created: #{post_7_title}"
      else
        unless post_7.header_img.attached?
          attach_header_image(post_7, "Business-Matching.jpg")
        end
        puts "  → Already exists: #{post_7_title}"
      end

      puts "\n" + "=" * 80
      puts "✅ RESOURCES SEEDING COMPLETE"
      puts "=" * 80
      puts "\nSummary:"
      puts "  Total Resource Topics: #{ResourceTopic.count}"
      puts "  Total Resource Categories: #{ResourceCategory.count}"
      puts "  Total Resource Media Types: #{ResourceMediaType.count}"
      puts "  Total Resource Write Permissions: #{ResourceWritePermission.count}"
      puts "  Total Published Resources: #{Resource.where(status: :published).count}"
      puts "    - Priority 1 Posts: #{Resource.where(priority: 1).count}"
      puts "    - Priority 2 Posts: #{Resource.where(priority: 2).count}"
      puts "\n✓ All posts assigned to: #{author.email}"
    end
  end
end
