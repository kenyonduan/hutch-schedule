require 'active_support/concern'
require 'active_support/core_ext/object/blank'
require 'hutch/schedule'
require 'ratelimit'

module Hutch
  # If consumer need `threshold`, just include this module. (included with Hutch::Enqueue)
  module Threshold
    extend ActiveSupport::Concern
    
    # Add Consumer methods
    class_methods do
      mattr_accessor :default_context, default: "default"
      mattr_accessor :default_rate, default: 10
      mattr_accessor :default_interval, default: 1
      
      # 限流速度:
      #  context: 可选的上下文, 默认为 default
      #  rate: 数量
      #  interval: 间隔
      #
      #  block: 采用 lambada 的方式计算, 但需要返回三个参数:
      #   - context: 当前约束的上下文
      #   - rate: 数量
      #   - interval: 间隔
      # 例如:
      #  - rate: 1, interval: 1, 每秒 1 个
      #  - rate: 30, interval: 1, 每秒 30 个
      #  - rate: 30, interval: 5, 每 5 s, 30 个
      def threshold(args)
        @block_given = args.is_a?(Proc)
        if @block_given
          @threshold_block = args
        else
          raise "need args or block" if args.blank?
          raise "args need hash type" if args.class != Hash
          args.symbolize_keys!
          @context  = args[:context].presence || default_context
          @rate     = args[:rate].presence || default_rate
          @interval = args[:interval].presence || default_interval
        end
        # call redis.ping let fail fast if redis is not avalible
        Hutch::Schedule.redis.ping
        # redis: 传入设置的 redis
        # bucket_interval: 记录的间隔, 越小精度越大
        @rate_limiter = Ratelimit.new(self.name,
                                      bucket_interval: Hutch::Config.get(:ratelimit_bucket_interval),
                                      redis:           Hutch::Schedule.redis)
      end
      
      # is class level @rate_limiter _context exceeded?
      # if class level @rate_limiter is nil alwayt return false
      def ratelimit_exceeded?
        return false if @rate_limiter.blank?
        @rate_limiter.exceeded?(_context, threshold: _rate, interval: _interval)
      rescue Redis::BaseError
        # when redis cann't connect return exceeded limit
        true
      end
      
      # 增加一次调用
      def ratelimit_add
        return if @rate_limiter.blank?
        @rate_limiter.add(_context)
      rescue Redis::BaseError
        nil
      end
      
      def _context
        @block_given ? @threshold_block.call[:context].presence || default_context : @context
      end
      
      def _rate
        @block_given ? @threshold_block.call[:rate].presence || default_rate : @rate
      end
      
      def _interval
        @block_given ? @threshold_block.call[:interval].presence || default_interval : @interval
      end
    end
  end
end

