# encoding: utf-8

# YaST namespace
module Yast
  # Main file
  class NfsClient < Client
    def main
      Yast.import "UI"

      textdomain "nfs"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("NFS module started")

      Yast.import "Nfs"
      Yast.import "NfsOptions"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "String"
      Yast.import "Summary"

      Yast.import "CommandLine"

      Yast.include self, "nfs/wizards.rb"

      @cmdline_description = {
        "id"         => "nfs",
        # Command line help text for the nfs module
        "help"       => _(
          "Configuration of NFS client"
        ),
        "guihandler" => fun_ref(method(:NfsSequence), "any ()"),
        "initialize" => fun_ref(Nfs.method(:Read), "boolean ()"),
        "finish"     => fun_ref(Nfs.method(:Write), "boolean ()"),
        "actions"    => {
          "list"   => {
            # TODO summary is probably better...
            "handler" => fun_ref(
              method(:NfsListHandler),
              "boolean (map)"
            ),
            # command line action help
            "help"    => _(
              "List configured NFS mounts"
            )
          },
          "add"    => {
            "handler" => fun_ref(method(:NfsAddHandler), "boolean (map)"),
            # command line action help
            "help"    => _("Add an NFS mount")
          },
          "edit"   => {
            "handler" => fun_ref(method(:NfsEditHandler), "boolean (map)"),
            # command line action help
            "help"    => _("Edit an NFS mount")
          },
          "delete" => {
            "handler" => fun_ref(method(:NfsDeleteHandler), "boolean (map)"),
            # command line action help
            "help"    => _("Delete an NFS mount")
          }
        },
        "options"    => {
          # TODO adjust names? create comaptibility aliases?
          "spec"   => {
            "type" => "string",
            # host:path
            # command line option help
            # fstab(5): fs_spec
            "help" => _(
              "Remote file system (in the form 'host:path')"
            )
          },
          "file"   => {
            "type" => "string",
            # path
            # command line option help
            # fstab(5): fs_file
            "help" => _(
              "Local mount point"
            )
          },
          # use defaults when not specified? describe in help?
          "mntops" => {
            "type" => "string",
            # a list?
            # command line option help
            # fstab(5): fs_mntops
            "help" => _(
              "Mount options"
            )
          },
          "type"   => {
            "type" => "string",
            # nfs or nfs4
            # command line option help
            # fstab(5): fs_type
            "help" => _(
              "File system ID, supported nfs and nfs4. Default value is nfs."
            )
          }
        },
        "mappings"   => {
          "list"   => [],
          "add"    => ["spec", "file", "mntops", "type"],
          # either of spec and file is key
          "edit"   => [
            "spec",
            "file",
            "mntops",
            "type"
          ],
          # either of spec and file is key
          "delete" => ["spec", "file"]
        }
      }

      # main ui function
      @ret = nil

      @ret = CommandLine.Run(@cmdline_description)
      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("NFS module finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end

    # CLI action handler.
    # Print summary in command line
    # @param [Hash] options command options
    # @return false so that Write is not called in non-interactive mode
    def NfsListHandler(_options)
      nfs_entries = deep_copy(Nfs.nfs_entries)
      if Ops.less_than(Builtins.size(nfs_entries), 1)
        CommandLine.Print(Summary.NotConfigured)
        return false
      end
      items = []
      Builtins.foreach(FstabTableItems(nfs_entries)) do |i|
        items = Builtins.add(
          items,
          [
            Ops.get_string(i, 1, ""),
            Ops.get_string(i, 2, ""),
            Ops.get_string(i, 3, ""),
            Ops.get_string(i, 4, "")
          ]
        )
      end

      CommandLine.Print(
        String.TextTable(
          [
            _("Server") + "  ",
            _("Remote File System") + "  ",
            _("Mount Point") + "  ",
            _("Options") + "  "
          ],
          items,
          {}
        )
      )
      false
    end

    # CLI action handler.
    # @param [Hash] options command options
    # @return whether successful
    def NfsAddHandler(options)
      options = deep_copy(options)
      nfs_entries = deep_copy(Nfs.nfs_entries)

      specl = Builtins.splitstring(Ops.get_string(options, "spec", ""), ":")
      server = Ops.get_string(specl, 0, "")
      pth = Ops.get_string(specl, 1, "")
      mount = Ops.get_string(options, "file", "")
      existing = Convert.convert(
        Builtins.union(Nfs.non_nfs_entries, nfs_entries),
        :from => "list",
        :to   => "list <map>"
      )

      if !CheckHostName(server) || !CheckPath(pth) || !CheckPath(mount) ||
          IsMpInFstab(existing, mount)
        return false
      end

      if !Builtins.haskey(options, "mntops")
        Ops.set(options, "mntops", "defaults")
      end

      options_error = NfsOptions.validate(Ops.get_string(options, "mntops", ""))
      if Ops.greater_than(Builtins.size(options_error), 0)
        Report.Error(options_error)
        return false
      end

      type = Ops.get_string(options, "type", "nfs")
      if type != "nfs" && type != "nfs4"
        Report.Error(_("Unknown value for option \"type\"."))
        return false
      end
      Ops.set(options, "vfstype", type)

      nfs_entries = Builtins.add(
        nfs_entries,
        Convert.convert(options, :from => "map", :to => "map <string, any>")
      )
      Nfs.nfs_entries = deep_copy(nfs_entries)
      true
    end

    # CLI action handler.
    # @param [Hash] options command options
    # @return whether successful
    def NfsEditHandler(options)
      options = deep_copy(options)
      nfs_entries = deep_copy(Nfs.nfs_entries)

      spec = Ops.get_string(options, "spec", "")
      file = Ops.get_string(options, "file", "")

      if spec == "" && file == ""
        # error
        CommandLine.Print(_("No NFS mount specified."))
        return false
      end

      type = Ops.get_string(options, "type", "nfs")
      if type != "nfs" && type != "nfs4"
        Report.Error(_("Unknown value for option \"type\"."))
        return false
      end
      Ops.set(options, "vfstype", type) if Builtins.haskey(options, "type")

      entries = []
      i = 0
      Builtins.foreach(nfs_entries) do |entry2|
        if Ops.get_string(entry2, "spec", "") == spec ||
            Ops.get_string(entry2, "file", "") == file
          entries = Builtins.add(entries, i)
          Builtins.y2internal("to change: %1", entry2)
        end
        i = Ops.add(i, 1)
      end
      if Builtins.size(entries) == 0
        # error message
        CommandLine.Print(_("No NFS mount matching the criteria found."))
        return false
      end
      if Ops.greater_than(Builtins.size(entries), 1)
        items = []
        Builtins.foreach(FstabTableItems(nfs_entries)) do |i2|
          items = Builtins.add(
            items,
            [
              Ops.get_string(i2, 1, ""),
              Ops.get_string(i2, 2, ""),
              Ops.get_string(i2, 3, ""),
              Ops.get_string(i2, 4, "")
            ]
          )
        end

        # error message
        CommandLine.Print(_("Multiple NFS mounts match the criteria:"))
        Builtins.foreach(entries) do |e|
          entry2 = Ops.get(nfs_entries, e, {})
          CommandLine.Print(
            Builtins.sformat(
              "spec=%1, file=%2",
              Ops.get_string(entry2, "spec", ""),
              Ops.get_string(entry2, "file", "")
            )
          )
        end
        return false
      end

      # now edit existing entry and check the validity
      entryno = Ops.get(entries, 0, 0)
      entry = Builtins.union(Ops.get(nfs_entries, entryno, {}), options)

      specl = Builtins.splitstring(Ops.get_string(entry, "spec", ""), ":")
      server = Ops.get_string(specl, 0, "")
      pth = Ops.get_string(specl, 1, "")
      mount = Ops.get_string(entry, "file", "")
      existing = Convert.convert(
        Builtins.union(
          Nfs.non_nfs_entries,
          Builtins.remove(nfs_entries, entryno)
        ),
        :from => "list",
        :to   => "list <map>"
      )

      if !CheckHostName(server) || !CheckPath(pth) || !CheckPath(mount) ||
          IsMpInFstab(existing, mount)
        return false
      end

      options_error = NfsOptions.validate(Ops.get_string(entry, "mntops", ""))
      if Ops.greater_than(Builtins.size(options_error), 0)
        Report.Error(options_error)
        return false
      end

      Ops.set(
        nfs_entries,
        entryno,
        Convert.convert(entry, :from => "map", :to => "map <string, any>")
      )
      Nfs.nfs_entries = deep_copy(nfs_entries)
      true
    end

    # CLI action handler.
    # @param [Hash] options command options
    # @return whether successful
    def NfsDeleteHandler(options)
      options = deep_copy(options)
      nfs_entries = deep_copy(Nfs.nfs_entries)

      spec = Ops.get_string(options, "spec", "")
      file = Ops.get_string(options, "file", "")

      if spec == "" && file == ""
        # error
        CommandLine.Print(_("No NFS mount specified."))
        return false
      end
      deleted = false
      nfs_entries = Builtins.filter(nfs_entries) do |entry|
        if spec != "" && Ops.get_string(entry, "spec", "") != spec ||
            file != "" && Ops.get_string(entry, "file", "") != file
          next true
        else
          deleted = true
          next false
        end
      end

      Nfs.nfs_entries = deep_copy(nfs_entries)
      deleted
    end
  end
end

Yast::NfsClient.new.main
