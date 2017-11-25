# Jets::Cfn::TemplateBuilders does not stick to the TemplateBuilders::Interface.
# It builds the properties of a function. Usage:
#
#   builder = FunctionPropertiesBuilder.new(task)
#   buider.properties
#   buider.map.logical_id # to access Function's logical id
#
class Jets::Cfn::TemplateBuilders
  class FunctionPropertiesBuilder
    def initialize(task)
      @task = task
    end

    def map
      @map ||= Jets::Cfn::TemplateMappers::LambdaFunctionMapper.new(@task)
    end

    def properties
      env_file_properties
        .deep_merge(global_properties)
        .deep_merge(class_properties)
        .deep_merge(function_properties)
        .deep_merge(fixed_properties)
    end

    def global_properties
      baseline = {
        Code: {
          S3Bucket: {Ref: "S3Bucket"}, # from child stack
          S3Key: map.code_s3_key
        },
        Role: { Ref: "IamRole" },
        Environment: { Variables: map.environment },
      }.deep_stringify_keys

      app_config_props = Jets.application.config.function.to_h
      app_config_props = pascalize(app_config_props.deep_stringify_keys)

      baseline.deep_merge(app_config_props)
    end

    def class_properties
      # klass is PostsController, HardJob, Hello, or HelloFunction
      klass = Jets::Klass.from_task(@task)
      class_properties = klass.class_properties
      pascalize(class_properties.deep_stringify_keys)
    end

    def function_properties
      pascalize(@task.properties.deep_stringify_keys)
    end

    # Do not allow overriding of fixed properties. Changing properties will
    # likely cause issues with Jets.
    def fixed_properties
      {
        FunctionName: map.function_name,
        Handler: map.handler,
      }
    end

    def env_file_properties
      env_vars = Jets::Dotenv.load!
      pascalize(environment: { variables: env_vars })
    end

  private
    # Specialized pascalize that will not pascalize keys under the
    # Variables part of the hash structure.
    # Based on: https://stackoverflow.com/questions/8706930/converting-nested-hash-keys-from-camelcase-to-snake-case-in-ruby
    def pascalize(value, parent_key=nil)
      case value
        when Array
          value.map { |v| pascalize(v) }
        when Hash
          initializer = value.map do |k, v|
            new_key = pascal_key(k, parent_key)
            [new_key, pascalize(v, new_key)]
          end
          Hash[initializer]
        else
          value
       end
    end

    def pascal_key(k, parent_key=nil)
      if parent_key == "Variables" # do not pascalize keys anything under Variables
        k
      else
        k = k.to_s.camelize
        k.slice(0,1).capitalize + k.slice(1..-1) # capitalize first letter only
      end
    end
  end
end
