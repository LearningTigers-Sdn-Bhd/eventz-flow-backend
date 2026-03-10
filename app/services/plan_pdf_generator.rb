require 'prawn'

class PlanPdfGenerator
  def initialize(plan)
    @plan = plan
  end

  def generate
    Prawn::Document.new(page_size: 'A4', page_layout: :landscape) do |pdf|
      pdf.text @plan.name, size: 20, style: :bold
      
      pdf_w = pdf.bounds.width
      pdf_h = pdf.bounds.height
      
      # Scale calculation
      # Ensure canvas dims are valid
      cw = @plan.canvas_width.to_f
      ch = @plan.canvas_height.to_f
      cw = 1000.0 if cw <= 0
      ch = 800.0 if ch <= 0

      scale = [pdf_w / cw, pdf_h / ch].min * 0.9 # 90% fit
      
      offset_x = (pdf_w - (cw * scale)) / 2
      offset_y = (pdf_h - (ch * scale)) / 2

      # Draw border for canvas
      pdf.stroke_rectangle [offset_x, pdf_h - offset_y], cw * scale, ch * scale

      @plan.plan_objects.includes(table_assignments: :ticket).each do |obj|
        # Coords: Web (Top-Left) -> PDF (Bottom-Left)
        # Web: (x, y) is top-left of object
        # Prawn: (0,0) is bottom-left. y increases upwards.
        
        draw_x = offset_x + (obj.x * scale)
        # Web y=0 is top. Prawn y=pdf_h is top.
        draw_y = pdf_h - (offset_y + (obj.y * scale))
        
        w = obj.width * scale
        h = obj.height * scale
        
        if obj.object_type_table?
          # Draw Table
          pdf.stroke_color "000000"
          
          if (obj.width - obj.height).abs < 1.0
             # Circle
             radius = w / 2
             center = [draw_x + radius, draw_y - radius]
             pdf.stroke_circle center, radius
          else
             # Rect
             pdf.stroke_rectangle [draw_x, draw_y], w, h
          end
          
          # Label
          pdf.bounding_box([draw_x, draw_y], width: w, height: h) do
             # Simple vertical centering attempt
             pdf.text_box obj.label || "", at: [0, h], width: w, height: h, align: :center, valign: :center, size: [8, w/4].min
          end
          
        elsif obj.object_type_wall?
           pdf.fill_color "CCCCCC"
           pdf.fill_rectangle [draw_x, draw_y], w, h
           pdf.fill_color "000000"
        elsif obj.object_type_stage?
           pdf.fill_color "EEEEEE"
           pdf.fill_rectangle [draw_x, draw_y], w, h
           pdf.fill_color "000000"
           pdf.text_box "STAGE", at: [draw_x, draw_y], width: w, height: h, align: :center, valign: :center
        elsif obj.object_type_label?
           pdf.text_box obj.label || "", at: [draw_x, draw_y], width: w, height: h, align: :center
        end
      end
    end.render
  end
end
