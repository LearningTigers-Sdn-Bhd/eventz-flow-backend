module SharedSchemas
  SUCCESS_RESPONSE_SCHEMA = {
    type: :object,
    properties: {
      success: { type: :boolean, example: true },
      data: { type: :object },
      message: { type: :string, example: 'Success' }
    }
  }.freeze
end
