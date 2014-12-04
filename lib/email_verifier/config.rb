module EmailVerifier
  module Config
    class << self
      attr_accessor :verifier_email

      def verifier_domain
        @verifier_domain ||= verifier_email.split("@").last
      end

      def reset
        @verifier_email = "nobody@nonexistant.com"
        @verifier_domain = nil
      end
    end
    self.reset
  end
end
