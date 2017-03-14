require "better_enum/version"

module BetterEnum
# Wrapper to Mongoid::Enum
# => Works exactly like Mongoid::Enum
#
#   Usage: 
#     include BetterEnum
#     bnum        :state, [:active, :inactive, :archived], default: :active
#
# => Better because:
#     1. Auto ChangeLog
#         - Accessed using obj.bnum_logs[:field_name]
#         - Set obj.bnum_actor the info about the actor
#         - Any narration/reason etc can be set in obj.bnum_remark

  extend ActiveSupport::Concern
  include Mongoid::Enum

  # ----------------------------------------------------------------------------
  # HELPERS
  # ----------------------------------------------------------------------------
  def bnum_state_as_on(date, field)

    date = date.to_date
    self.bnum_logs[field] ||= []
    sorted_history = self.bnum_logs[field].sort_by {|rec| rec[:when]}

    selected_rec = nil
    if sorted_history.last[:when] < date
      selected_rec = sorted_history.last
    end

    sorted_history.each_with_index do |rec, idx|
      break if selected_rec

      if rec[:when] > date
        selected_rec = (idx == 0) ? rec : sorted_history[idx - 1]
      end
    end

    selected_rec[:what].last
  end

  # ----------------------------------------------------------------------------
  # UNDER THE HOOD STUFF -------------------------------------------------------
  # ----------------------------------------------------------------------------
  included do

    @bnum_actor
    @bnum_remark
    attr_accessor :bnum_actor, :bnum_remark
    
    field :_bnh, as: :bnum_logs, type: Hash, default: Hash.new([])

    before_save do
      if self.changes.present?
        self.class.bnum_fields.each do |f|
          f_changes = self.changes["_#{f}"]

          next if f_changes.blank?
          next if f_changes == @prev_f_changes

          # Somehow before_save is being called twice in case of receipt cancellation
          # putting this check to avoid repetition of logs
          @prev_f_changes = f_changes

          self.bnum_logs[f] ||= []
          self.bnum_logs[f].push( {
                                    who:    @bnum_actor.to_s,
                                    why:    @bnum_remark.to_s,
                                    when:   Time.now, 
                                    what:   f_changes # Format: [prev_value, new_value]
                                  })
        end
      end
    end
  end

  module ClassMethods

    cattr_accessor :bnum_fields
    @bnum_fields = []

    def bnum(field, states, options = {})

      enum(field.to_sym, Array.wrap(states), options)

      self.bnum_fields ||= []
      self.bnum_fields |= [field.to_sym]
    end
  end
end