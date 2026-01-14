# Pagy initializer file (config/initializers/pagy.rb)

# Default limit per page (was items)
Pagy.options[:limit] = 25

# Maximum items per page allowed (client requested)
Pagy.options[:client_max_limit] = 100

# Maximum page number allowed
Pagy.options[:max_pages] = 1000

# Set to false if you want to disable the overflow handling
Pagy.options[:overflow] = :empty_page
