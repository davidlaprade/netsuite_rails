module NetSuiteRails
  module SyncTrigger
    extend self

    # TODO think about a flag to push to NS on after_validation vs after_commit
    # TODO think about background async record syncing (re: multiple sales order updates)
    # TODO need to add hook for custom proc to determine if data should be pushed to netsuite
    #      if a model has a pending/complete state we might want to only push on complete

    def attach(klass)
      # don't attach to non-AR backed models
      return unless klass.ancestors.include?(ActiveRecord::Base)

      if klass.include?(SubListSync)
        klass.after_save { SyncTrigger.sublist_trigger(self) }
        klass.after_destroy { SyncTrigger.sublist_trigger(self) }
      elsif klass.include?(RecordSync)

        # during the initial pull we don't want to push changes up
        klass.before_save do
          @netsuite_sync_record_import = self.new_record? && self.netsuite_id.present?

          # if false record will not save
          true
        end

        klass.after_save do
          # need to implement this conditional on the save hook level
          # because the coordination class doesn't know about model persistence state

          if @netsuite_sync_record_import
            # pull the record down if it has't been pulled yet
            # this is useful when this is triggered by a save on a parent record which has this
            # record as a related record

            unless self.netsuite_pulled?
              SyncTrigger.record_pull_trigger(self)
            end
          else
            SyncTrigger.record_push_trigger(self)
          end

          @netsuite_sync_record_import = false
        end
      end

      # TODO think on NetSuiteRails::ListSync
    end

    def record_pull_trigger(local)
      return if NetSuiteRails::Configuration.netsuite_pull_disabled

      sync_options = local.netsuite_sync_options

      return if sync_options.has_key?(:pull_if) && !local.instance_exec(&sync_options[:pull_if])

      record_trigger_action(local, :netsuite_pull)
    end

    def record_push_trigger(netsuite_record_rep)
      # don't update when fields are updated because of a netsuite_pull
      return if netsuite_record_rep.netsuite_pulling?

      return if NetSuiteRails::Configuration.netsuite_push_disabled

      # don't update if a read only record
      return if netsuite_record_rep.netsuite_sync == :read

      sync_options = netsuite_record_rep.netsuite_sync_options

      # :if option is a block that returns a boolean
      return if sync_options.has_key?(:if) && !netsuite_record_rep.instance_exec(&sync_options[:if])

      record_trigger_action(netsuite_record_rep, :netsuite_push)
    end

    def record_trigger_action(local, action)
      sync_options = local.netsuite_sync_options

      action_options = {

      }

      if sync_options.has_key?(:credentials)
        action_options[:credentials] = local.instance_exec(&sync_options[:credentials])
      end

      # TODO need to pass off the credentials to the NS push command
      
      # You can force sync mode in different envoirnments with the global configuration variables

      if sync_options[:mode] == :sync || NetSuiteRails::Configuration.netsuite_sync_mode == :sync
        local.send(action, action_options)
      else
        action_options[:modified_fields] = NetSuiteRails::RecordSync::PushManager.modified_local_fields(local).keys

        # TODO support the rails4 DJ implementation

        if local.respond_to?(:delay)
          local.delay.send(action, action_options)
        else
          raise 'no supported delayed job method found'
        end
      end
    end

    def sublist_trigger(sublist_item_rep)
      # TODO don't trigger a push if the parent record is still pulling
      # often sublists are managed in a after_pull hook; we want to prevent auto-pushing
      # if sublist records are being updated. However, the netsuite_pulling? state is not persisted
      # so there is no gaurentee that it isn't being pulled by checking parent.netsuite_pulling?

      parent = sublist_item_rep.send(sublist_item_rep.class.netsuite_sublist_parent)
      
      if parent.class.include?(RecordSync)
        record_push_trigger(parent)
      end
    end

  end
end