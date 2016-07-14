require "tsort"

# Namespace for code related to /etc/fstab
module Fstab
  # Simple module implementing topological sorting for fstab entries
  module TSort
    extend Yast::Logger

    # Sorts a list of fstab entries by the topological order of the mount points
    def self.sort(list)
      # Define the two iterators required by TSort
      each_node = list.reverse.method(:each)
      each_child = lambda do |n, &b|
        list.select { |e| dependent_mount_point?(e["file"], n["file"]) }.each(&b)
      end
      # Let TSort do the job
      begin
        ::TSort.tsort(each_node, each_child).reverse
      rescue ::TSort::Cyclic
        log.error "Oops, a cycle in fstab?"
        list.dup
      end
    end

    # Checks if the first mount point requires the second one to be mounted in
    # advance
    def self.dependent_mount_point?(dependent, root)
      return false if root == dependent

      root += "/" unless root.end_with?("/")
      dependent += "/" unless dependent.end_with?("/")
      dependent.start_with?(root)
    end

    private_class_method :dependent_mount_point?
  end
end
