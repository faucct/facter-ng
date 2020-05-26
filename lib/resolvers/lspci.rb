# frozen_string_literal: true

module Facter
  module Resolvers
    class Lspci < BaseResolver
      @semaphore = Mutex.new
      @fact_list ||= {}

      REGEX_VALUES = { 'VirtualBox' => 'virtualbox', 'XenSource' => 'xenhvm',
                       'Microsoft Corporation Hyper-V' => 'hyperv', 'Class 8007: Google, Inc' => 'gce' }.freeze

      class << self
        private

        def post_resolve(fact_name)
          @fact_list.fetch(fact_name) { lspci_command(fact_name) }
        end

        def lspci_command(fact_name)
          output = Facter::Core::Execution.execute('lspci', logger: log)
          return if output.empty?

          @fact_list[:vm] = retrieve_vm(output)
          @fact_list[fact_name]
        end

        def retrieve_vm(output)
          output.split("\n").each do |line|
            REGEX_VALUES.each { |key, value| return value if line =~ /#{key}/ }

            return 'vmware' if line =~ /VM[wW]are/
            return 'parallels' if line =~ /1ab8:|[Pp]arallels/
            return 'kvm' if line =~ /virtio/i
          end
        end
      end
    end
  end
end
