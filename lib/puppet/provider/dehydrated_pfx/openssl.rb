require 'pathname'
require 'openssl'
Puppet::Type.type(:dehydrated_pfx).provide(:openssl) do
  desc 'Manages pkcs12/pfx file creation with OpenSSL'

  def self.certificate(filename, read_array)
    file = File.read(filename)
    if read_array
      file.split('-----BEGIN ').select{ |cert| cert =~ /^CERTIFICATE.*/}.map do |cert|
        OpenSSL::X509::Certificate.new('-----BEGIN ' + cert)
      end
    else
      OpenSSL::X509::Certificate.new(file)
    end
  end

  def self.private_key(resource)
    file = File.read(resource[:private_key])
    if (file =~ /BEGIN PUBLIC KEY/)
      OpenSSL::PKey::RSA.new(file, resource[:key_password])
    elsif (file =~ /BEGIN EC PRIVATE KEY/)
      OpenSSL::PKey::EC.new(file, resource[:key_password])
    else
      raise Puppet::Error, "Unknown private key type"
    end
  end

  def exists?
    if File.exist?(resource[:path])
      begin
        pfx = OpenSSL::PKCS12.new(File.read(resource[:path]))
        ca = self.class.certificate(resource[:ca], true)
        cert = self.class.certificate(resource[:certificate], false)
        key = self.class.private_key(resource)
        pfx.ca_certs == ca && pfx.certificate == cert && pfx.key == key
      rescue OpenSSL::PKCS12::PKCS12Error
        false
      rescue OpenSSL::X509::CertificateError
        false
      rescue OpenSSL::PKey::ECError
        false
      rescue OpenSSL::PKey::RSAError
        false
      end
    else
      false
    end
  end

  def create
    ca = self.class.certificate(resource[:ca], true)
    cert = self.class.certificate(resource[:certificate], false)
    key = self.class.private_key(resource)

    pfx = OpenSSL::PKCS12.create(
      resource[:password],
      resource[:name],
      key,
      cert,
      ca,
    )

    File.write(resource[:path], pfx.to_der())
  end

  def destroy
    Pathname.new(resource[:path]).delete
  end
end
