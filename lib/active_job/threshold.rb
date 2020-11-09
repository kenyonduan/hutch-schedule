module ActiveJob
  module Threshold
    extend ActiveSupport::Concern

    included do
      class_attribute :threshold_args, default: nil
    end

    module ClassMethods
      def threshold(args)
        self.threshold_args = args
      end
    end
  end

  class Base
    include Threshold
  end
end