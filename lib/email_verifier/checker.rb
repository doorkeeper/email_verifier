require 'net/smtp'
require 'dnsruby'

class EmailVerifier::Checker

  ##
  # Returns server object for given email address or throws exception
  # Object returned isn't yet connected. It has internally a list of
  # real mail servers got from MX dns lookup
  def initialize(address)
    @email   = address
    @servers = list_mxs(address.split("@").last)
    raise EmailVerifier::NoMailServerException.new("No mail server for #{address}") if @servers.empty?
    @smtp    = nil
  end

  def list_mxs(domain)
    return [] unless domain.present?
    mxs = []
    resolver = Dnsruby::DNS.new
    resolver.each_resource(domain, 'MX') do |rr|
      mxs << { priority: rr.preference, address: rr.exchange.to_s }
    end
    mxs.sort_by { |mx| mx[:priority] }
  rescue Dnsruby::NXDomain
    raise EmailVerifier::NoMailServerException.new("#{domain} does not exist")
  end

  def is_connected
    !@smtp.nil?
  end

  def connect
    begin
      server = next_server
      raise EmailVerifier::OutOfMailServersException.new("Unable to connect to any one of mail servers for #{@email}") if server.nil?
      @smtp = Net::SMTP.new(server[:address], 25)
      @smtp.open_timeout = 5
      @smtp.read_timeout = 5
      @smtp.start(EmailVerifier.config.verifier_domain)
      return true
    rescue EmailVerifier::OutOfMailServersException => e
      raise EmailVerifier::OutOfMailServersException, e.message
    rescue => e
      retry
    end
  end

  def next_server
    @servers.shift
  end

  def verify
    self.mailfrom(EmailVerifier.config.verifier_email)
    self.rcptto(@email)
  end

  def mailfrom(address)
    ensure_connected

    ensure_250 @smtp.mailfrom(address)
  end

  def rcptto(address)
    ensure_connected

    begin
      ensure_250 @smtp.rcptto(address)
    rescue => e
      if e.message[/^550/]
        return false
      else
        raise EmailVerifier::FailureException.new(e.message)
      end
    end
  end

  def ensure_connected
    raise EmailVerifier::NotConnectedException.new("You have to connect first") if @smtp.nil?
  end

  def ensure_250(smtp_return)
    if smtp_return.status.to_i == 250
      return true
    else
      raise EmailVerifier::FailureException.new "Mail server responded with #{smtp_return.status} when we were expecting 250"
    end
  end

end
