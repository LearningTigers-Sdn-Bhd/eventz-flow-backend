# Pagy initializer file (config/initializers/pagy.rb)

# Default limit per page (was items)
Pagy::OPTIONS[:limit] = 25

# Maximum items per page allowed (client requested)
Pagy::OPTIONS[:max_limit] = 100

# Maximum page number allowed
# ponytail: deprecated in pagy 43.6 in favor of https://ddnexus.github.io/pagy/guides/how-to/#paginate-only-max-records
# still functional (warning only) — revisit if pagy drops the fallback in a future major
Pagy::OPTIONS[:max_pages] = 1000

# Set to false if you want to disable the overflow handling
Pagy::OPTIONS[:overflow] = :empty_page
