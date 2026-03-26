class PublicRegistrationErrorPageRenderer
  def self.call(title:, message:)
    new(title: title, message: message).call
  end

  def initialize(title:, message:)
    @title = ERB::Util.html_escape(title)
    @message = ERB::Util.html_escape(message)
  end

  def call
    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>#{@title}</title>
        <style>
          :root {
            --bg-color: #0f1115;
            --card-bg: #161921;
            --border-color: #212631;
            --text-main: #f9fafb;
            --text-muted: #9ca3af;
            --error-color: #ef4444;
          }

          * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
          }

          body {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            background-color: var(--bg-color);
            color: var(--text-main);
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji";
            line-height: 1.5;
            padding: 20px;
          }

          .container {
            width: 100%;
            max-width: 480px;
            text-align: center;
            animation: fadeIn 0.5s ease-out;
          }

          @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
          }

          .card {
            background-color: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 24px;
            padding: 40px 32px;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
          }

          .icon-wrapper {
            width: 64px;
            height: 64px;
            background-color: rgba(239, 68, 68, 0.1);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 24px;
            color: var(--error-color);
          }

          h1 {
            font-size: 24px;
            font-weight: 700;
            margin-bottom: 12px;
            letter-spacing: -0.025em;
          }

          p {
            color: var(--text-muted);
            font-size: 16px;
          }

          .footer {
            margin-top: 32px;
            font-size: 13px;
            color: var(--text-muted);
          }

          svg {
            width: 32px;
            height: 32px;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <main class="card">
            <div class="icon-wrapper">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
              </svg>
            </div>
            <h1>#{@title}</h1>
            <p>#{@message}</p>
          </main>
          <footer class="footer">
            &copy; #{Time.current.year} Eventz Flow. All rights reserved.
          </footer>
        </div>
      </body>
      </html>
    HTML
  end
end
