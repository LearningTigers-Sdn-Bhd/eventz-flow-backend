require 'prawn'
require 'prawn/table'

Prawn::Fonts::AFM.hide_m17n_warning = true

class PlanPdfGenerator
  def initialize(plan)
    @plan = plan
  end

  def generate(type: 'map')
    local_plan = @plan
    layout = type == 'map' ? :landscape : :portrait
    
    pdf = Prawn::Document.new(page_size: 'A4', page_layout: layout, margin: [40, 40, 40, 40])
    
    pdf.font_families.update("Helvetica" => {
      normal: "Helvetica",
      bold: "Helvetica-Bold",
      italic: "Helvetica-Oblique"
    })
    pdf.font "Helvetica"

    if type == 'map'
      generate_map_page(pdf, local_plan)
    elsif type == 'ops'
      generate_ops_manifest(pdf, local_plan)
    elsif type == 'public'
      generate_public_list(pdf, local_plan)
    end

    pdf.number_pages "Page <page> of <total>", at: [pdf.bounds.right - 100, -10], size: 8
    pdf.render
  end

  private

  def generate_map_page(pdf, plan)
    # Subtle generation timestamp in the corner
    pdf.text_box Time.now.strftime("%d#{day_suffix(Time.now)} %B %Y, %I:%M%P (%a)"), 
                 at: [pdf.bounds.right - 150, pdf.bounds.top + 10], 
                 width: 150, align: :right, size: 7, color: "888888"

    pdf.text plan.event.title, size: 12, color: "666666"
    pdf.move_down 20

    pdf_w = pdf.bounds.width
    pdf_h = pdf.bounds.height - 50
    
    cw = plan.canvas_width.to_f
    ch = plan.canvas_height.to_f
    cw = 1000.0 if cw <= 0
    ch = 800.0 if ch <= 0

    scale = [pdf_w / cw, pdf_h / ch].min * 0.95
    offset_x = (pdf_w - (cw * scale)) / 2
    offset_y = (pdf_h - (ch * scale)) / 2

    if plan.background_image.attached?
      begin
        plan.background_image.open do |file|
          pdf.image file.path, at: [offset_x, pdf_h - offset_y], width: cw * scale, height: ch * scale
        end
      rescue; end
    end

    plan.plan_objects.each { |obj| draw_object(pdf, obj, offset_x, offset_y, scale, pdf_h) }
  end

  def generate_ops_manifest(pdf, plan)
    # Subtle generation timestamp in the corner
    pdf.text_box Time.now.strftime("%d#{day_suffix(Time.now)} %B %Y, %I:%M%P (%a)"), 
                 at: [pdf.bounds.right - 150, pdf.bounds.top + 10], 
                 width: 150, align: :right, size: 7, color: "888888"

    pdf.text plan.event.title, size: 12, color: "666666"
    pdf.move_down 20

    pdf.table([
      ["Total Tables", plan.plan_objects.object_type_table.count],
      ["Total Capacity", plan.plan_objects.object_type_table.sum(:capacity)],
      ["Assigned Guests", plan.table_assignments.count]
    ], width: 200, cell_style: { size: 9, padding: 4, border_width: 0.5 })
    
    pdf.move_down 30

    plan.plan_objects.object_type_table.order(:label).includes(table_assignments: [:ticket, :visitor]).each do |table|
      if pdf.cursor < 100; pdf.start_new_page; end
      
      pdf.fill_color "F3F4F6"
      pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 20
      pdf.fill_color "000000"
      pdf.pad(5) { pdf.indent(10) { pdf.text "#{table_display_name(table)} (Cap: #{table.capacity})", style: :bold, size: 10 } }
      
      # Sort assignments alphabetically by guest name
      assignments = table.table_assignments.sort_by { |asgn| (asgn.ticket&.attendee_name || asgn.visitor&.full_name || "").downcase }
      
      if assignments.empty?
        pdf.indent(10) { pdf.text "Empty", size: 8, style: :italic, color: "999999" }
      else
        rows = assignments.each_with_index.map do |asgn, idx|
          [idx + 1, asgn.ticket&.attendee_name || asgn.visitor&.full_name || "Guest", asgn.notes || "-"]
        end
        pdf.table([["#", "Name", "Notes"]] + rows, width: pdf.bounds.width) do
          row(0).font_style = :bold
          cells.padding = [4, 10]; cells.size = 8; cells.border_width = 0.1; cells.border_color = "CCCCCC"
          column(0).width = 25
        end
      end
      pdf.move_down 15
    end
  end

  def generate_public_list(pdf, plan)
    # Subtle generation timestamp in the corner
    pdf.text_box Time.now.strftime("%d#{day_suffix(Time.now)} %B %Y, %I:%M%P (%a)"), 
                 at: [pdf.bounds.right - 150, pdf.bounds.top + 10], 
                 width: 150, align: :right, size: 7, color: "888888"

    pdf.text plan.event.title, size: 14, color: "666666", align: :center
    pdf.move_down 40

    tables = plan.plan_objects.object_type_table.order(:label).includes(table_assignments: [:ticket, :visitor]).to_a
    
    column_width = (pdf.bounds.width / 2) - 15
    row_spacing = 30
    
    # Grid Logic: 2 tables per row, perfectly aligned heights per row
    tables.each_slice(2) do |row_pair|
      # Sort assignments for each table in the row
      sorted_row_pair = row_pair.map do |table|
        {
          table: table,
          assignments: table.table_assignments.sort_by { |asgn| (asgn.ticket&.attendee_name || asgn.visitor&.full_name || "").downcase }
        }
      end

      # Calculate max height needed for this row
      row_heights = sorted_row_pair.map do |data|
        count = data[:assignments].count
        count = 1 if count == 0 # "No guests" text
        15 + 2 + 8 + (count * 13) + 5
      end
      max_row_height = row_heights.max

      # Page break check
      if pdf.cursor < max_row_height
        pdf.start_new_page
      end

      initial_y = pdf.cursor

      sorted_row_pair.each_with_index do |data, i|
        table = data[:table]
        assignments = data[:assignments]
        x_pos = i == 0 ? 0 : column_width + 30
        
        pdf.bounding_box([x_pos, initial_y], width: column_width) do
          # Table Header
          pdf.fill_color "000000"
          pdf.text table_display_name(table), style: :bold, size: 12
          pdf.stroke_color "DDDDDD"
          pdf.stroke_horizontal_rule
          pdf.move_down 8

          # Guest List
          if assignments.empty?
            pdf.text "No guests assigned", size: 9, style: :italic, color: "999999"
          else
            assignments.each do |asgn|
              name = asgn.ticket&.attendee_name || asgn.visitor&.full_name || "Guest"
              pdf.text name, size: 10
              pdf.move_down 3
            end
          end
        end
      end

      # Move cursor to the bottom of the taller table
      pdf.move_cursor_to(initial_y - max_row_height - row_spacing)
    end
  end

  private

  # Table number is the operational identifier; label (e.g. sponsor name) is
  # shown alongside it when both are set, mirroring the canvas display.
  def table_display_name(table)
    if table.table_number.present? && table.label.present?
      "#{table.table_number} — #{table.label}"
    elsif table.table_number.present?
      "Table #{table.table_number}"
    else
      table.label.presence || "Table"
    end
  end

  def day_suffix(time)
    case time.day
    when 1, 21, 31 then "st"
    when 2, 22 then "nd"
    when 3, 23 then "rd"
    else "th"
    end
  end

  def draw_object(pdf, obj, offset_x, offset_y, scale, pdf_h)
    draw_x = offset_x + (obj.x * scale); draw_y = pdf_h - (offset_y + (obj.y * scale))
    w = obj.width * scale; h = obj.height * scale

    case obj.object_type
    when 'table'
      pdf.stroke_color "000000"; pdf.fill_color "FFFFFF"
      if (obj.width - obj.height).abs < 1.0
        radius = w / 2; pdf.fill_and_stroke_circle [draw_x + radius, draw_y - radius], radius
      else
        pdf.fill_and_stroke_rectangle [draw_x, draw_y], w, h
      end
      pdf.fill_color "000000"
      pdf.bounding_box([draw_x, draw_y], width: w, height: h) do
        text = [obj.table_number.presence, obj.label.presence].compact.join("\n")
        pdf.text_box text, at: [0, h], width: w, height: h, align: :center, valign: :center, size: [8, w/4].min
      end
    when 'floor'
      pdf.fill_color "FAFAFA"; pdf.stroke_color "E5E7EB"; pdf.fill_and_stroke_rectangle [draw_x, draw_y], w, h; pdf.fill_color "000000"
    when 'wall'
      pdf.fill_color "333333"; pdf.fill_rectangle [draw_x, draw_y], w, h; pdf.fill_color "000000"
    when 'stage'
      pdf.fill_color "F3F4F6"; pdf.stroke_color "D1D5DB"; pdf.fill_and_stroke_rectangle [draw_x, draw_y], w, h; pdf.fill_color "000000"
      pdf.text_box "STAGE", at: [draw_x, draw_y], width: w, height: h, align: :center, valign: :center, size: 10, style: :bold
    when 'label'
      pdf.text_box obj.label || "", at: [draw_x, draw_y], width: w, height: h, align: :center, valign: :center, size: 9
    end
  end
end
