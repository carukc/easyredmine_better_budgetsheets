module BetterBudgetsheetsHelper
  
  include SortHelper
  
  def bugdet_sheet_display_value_for(time_entry, col, options = {})
    value = nil

    @summed_up_values ||= {}

    # assignment, not comparing
    if cf = budget_sheet_cf_from_col_name(col)

      case cf.type
      when 'IssueCustomField' 
        value =time_entry.issue.custom_field_value(cf.id)
      when 'ProjectCustomField'
        value = time_entry.project.custom_field_value(cf.id)
      when 'TimeEntryCustomField'
        value = time_entry.custom_field_value(cf.id)
      end
      case cf.field_format
      when 'user'
        value = User.find_by(id: value)
      when 'int'
        value = value.to_i
      when 'date'
        value =  Date.parse(value)
      when 'datetime'    
        value =  DateTime.parse(value)
      end

    else
      value = time_entry.send(col)
    end
    
    if options[:value_only] == true
      value
    else
      if value.is_a?(Date) || value.is_a?(DateTime)
        value.to_de
      elsif value.is_a?(ActiveSupport::TimeWithZone)
        value.localtime.to_de
      elsif value.is_a?(Numeric)
        @summed_up_values[col] ||= {}
        suffix = budget_sheet_number_suffix(col, time_entry)
        @summed_up_values[col][suffix] ||= 0
        # grouping for different units

        @summed_up_values[col][suffix] += value
        value
      else
        value
      end
    end  
  end
  
  def sorted_entries(entries, sorting = nil)
    if sorting.present?
      sorting = Array.wrap(sorting)

      entries.sort_by do |e|
        sorting.map do |s|
          current_value = if s.is_a?(Array)
            x = bugdet_sheet_display_value_for(e, s[0], value_only: true)
            if x.is_a?(Numeric) || x.is_a?(Date) || x.is_a?(DateTime) || x.is_a?(ActiveSupport::TimeWithZone)
              s[1] == 'asc' ? x : x.to_i * -1
            else
              x
            end
          else
            bugdet_sheet_display_value_for(e,s, value_only: true)
          end
        end
      end
    else
      entries
    end
  end

  def bugdet_sheet_column_for(time_entry, col)
    v = bugdet_sheet_display_value_for(time_entry, col)
    css = ""
    if v.is_a?(Numeric)

      if budget_sheet_cf_from_col_name(col).try(:field_format) == 'int'
        v = v.to_de
      else  
        v = v.to_euro(budget_sheet_number_suffix(col, time_entry))
      end  
      css = "text-right"
    end

    content_tag :td, v.to_s.replace_entities, class: css
  end

  def budget_sheet_number_suffix(col, time_entry)
    if is_money_value?(col)
      if time_entry.project.easy_currency
        time_entry.project.easy_currency.symbol.presence || time_entry.project.easy_currency.iso_code.presence
      else
        ""
      end
    elsif col.match(/hour/)
      "h"
    else
      ""
    end
  end

  def is_money_value?(col)
    col.match(/rate|money/)
  end

  def budget_sheet_header_label(col)
    # first, checking if column in yaml file is present
    I18n.t(col, 
      scope: 'better_budgetsheets_columns',
      default: (budget_sheet_cf_from_col_name(col).try(:name) || I18n.t("field_#{col}"))
    ).replace_entities  
  end

  def budget_sheet_cf_from_col_name(col)
    @_cfs_from_cols ||= {}
    if col.to_s.match(/cf_/)
      @_cfs_from_cols[col] ||= CustomField.find(col.to_s.match(/[0-9]{1,}/).to_s)
    end
    @_cfs_from_cols[col]
  end

end