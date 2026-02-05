class QrCodeService
  def self.generate_png(data, size: 300)
    qr = RQRCode::QRCode.new(data)
    qr.as_png(
      size: size,
      border_modules: 2,
      color: "000",
      fill: "fff"
    ).to_s
  end

  def self.generate_svg(data, size: 300)
    qr = RQRCode::QRCode.new(data)
    qr.as_svg(
      viewbox: true,
      use_path: true,
      svg_attributes: { width: size, height: size }
    )
  end
end
