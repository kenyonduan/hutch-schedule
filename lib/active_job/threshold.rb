module ActiveJob
  module Threshold
    extend ActiveSupport::Concern

    included do
      class_attribute :threshold, default: nil
    end

    module ClassMethods
      def threshold(args)
        self.threshold = args
      end
    end
  end
end