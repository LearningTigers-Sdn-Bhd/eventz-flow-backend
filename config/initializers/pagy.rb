# Pagy initializer file (config/initializers/pagy.rb)

# Default limit per page (was items)
Pagy::OPTIONS[:limit] = 25

# Maximum items per page allowed (client requested)
Pagy::OPTIONS[:max_limit] = 100

# Maximum total records allowed (replaces deprecated max_pages: 1000 * limit 25)
# https://ddnexus.github.io/pagy/guides/how-to/#paginate-only-max-records
Pagy::OPTIONS[:max_records] = 25_000

# Set to false if you want to disable the overflow handling
Pagy::OPTIONS[:overflow] = :empty_page
