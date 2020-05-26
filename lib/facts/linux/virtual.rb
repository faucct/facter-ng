# frozen_string_literal: true

module Facts
  module Linux
    class Virtual
      FACT_NAME = 'virtual'
      HYPERVISORS_HASH = { 'VMware' => 'vmware', 'VirtualBox' => 'virtualbox', 'Parallels' => 'parallels',
                           'KVM' => 'kvm', 'Virtual Machine' => 'hyperv', 'RHEV Hypervisor' => 'rhev',
                           'oVirt Node' => 'ovirt', 'HVM domU' => 'xenhvm', 'Bochs' => 'bochs', 'OpenBSD' => 'vmm',
                           'BHYVE' => 'bhyve' }.freeze
      @bios_vendor = nil

      def call_the_resolver
        fact_value = check_docker_lxc || check_gce || retrieve_from_virt_what || check_vmware
        fact_value ||= check_other_facts || check_lspci || 'physical'

        Facter::ResolvedFact.new(FACT_NAME, fact_value)
      end

      def check_gce
        @bios_vendor = Facter::Resolvers::Linux::DmiBios.resolve(:bios_vendor)
        'gce' if @bios_vendor&.include?('Google')
      end

      def check_docker_lxc
        Facter::Resolvers::DockerLxc.resolve(:vm)
      end

      def check_vmware
        Facter::Resolvers::Vmware.resolve(:vm)
      end

      def retrieve_from_virt_what
        Facter::Resolvers::VirtWhat.resolve(:vm)
      end

      def check_other_facts
        product_name = Facter::Resolvers::Linux::DmiBios.resolve(:product_name)
        return 'kvm' if @bios_vendor&.include?('Amazon EC2')
        return unless product_name

        HYPERVISORS_HASH.each { |key, value| return value if product_name.include?(key) }
      end

      def check_lspci
        Facter::Resolvers::Lspci.resolve(:vm)
      end
    end
  end
end
