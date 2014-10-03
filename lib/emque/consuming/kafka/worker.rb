require "poseidon_cluster"

module Emque
  module Consuming
    module Kafka
      class Worker
        include Emque::Consuming::Actor
        trap_exit :actor_died

        attr_accessor :topic

        def actor_died(actor, reason)
          logger.error "Kafka Worker: actor_died - #{actor.inspect} died: #{reason}"
        end

        def initialize(topic)
          self.topic = topic
          self.fetcher = Emque::Consuming::Kafka::Fetcher.new_link(current_actor, topic)
          self.work_queues = {}
          self.name = "#{self.topic.capitalize} worker"
          self.shutdown = false
        end

        def start
          logger.info "Kafka Worker: #{name} starting..."
          work
        end

        def stop
          logger.info "Kafka Worker: #{name} stopping..."
          self.shutdown = true
          fetcher.stop
        end

        def push_work(partition, messages)
          if messages.size > 0
            logger.info "Kafka Worker received #{messages.count} " +
                        "messages on partition #{partition}"

            work_queues[partition] ||= []
            work_queues[partition] += messages
          end

          after(1) { work }
        end

        private

        attr_accessor :name, :consumer_klass, :fetcher, :shutdown, :work_queues

        def fetch_work
          partition, queue = next_job

          if queue
            if fetcher.has_partition?(partition)
              return {:partition => partition, :message => queue.pop}
            else
              work_queues.delete(partition)
              fetch_work
            end
          else
            :not_found
          end
        end

        def next_job
          work_queues.find { |key, value| !value.empty? }
        end

        def work
          unless shutdown
            job = fetch_work

            if job.is_a?(Hash)
              logger.info "#{name} processing message #{job[:message].value} " +
                "from partition #{job[:partition]}"

              fetcher.async.commit(job[:partition], job[:message].offset)

              message = Emque::Consuming::Message.new(
                :offset => job[:message].offset,
                :original => job[:message].value,
                :partition => job[:partition],
                :topic => job[:message].topic.to_sym
              )

              ::Emque::Consuming::Consumer.new.consume(:process, message)

              after(0) { work }
            else
              fetcher.async.fetch
            end
          end
        end
      end
    end
  end
end
