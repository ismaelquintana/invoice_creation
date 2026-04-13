ExUnit.start()
Faker.start()

# Load test support modules
Code.require_file("support/test_helpers.ex", __DIR__)
Code.require_file("support/data_case.ex", __DIR__)
Code.require_file("support/factory.ex", __DIR__)
