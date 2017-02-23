##
# Redefine +Logger+ from stdlib, so it can both log and report errors to
# Airbrake.
#
# @example
#   # Create a logger like you normally do.
#   logger = Logger.new(STDOUT)
#
#   # Assign a default Airbrake notifier
#   logger.airbrake = Airbrake[:default]
#
#   # Just use the logger like you normally do.
#   logger.fatal('oops')
class Logger
  # Store the orginal method to use it later.
  alias add_without_airbrake add

  ##
  # @return [Airbrake::Notifier] notifier to be used to send notices
  attr_accessor :airbrake

  ##
  # @see Logger#add
  def add(severity, message = nil, progname = nil)
    notify_airbrake(message || progname, severity) if airbrake
    add_without_airbrake(severity, message, progname)
  end

  private

  def notify_airbrake(message, severity)
    notice = Airbrake.build_notice(message || progname)

    # Get rid of unwanted internal Logger frames.
    # Example: /ruby-2.4.0/lib/ruby/2.4.0/logger.rb
    notice[:errors].first[:backtrace].shift

    notice[:context][:component] = 'logger'
    notice[:context][:severity] = airbrake_severity(severity)

    Airbrake.notify(notice)
  end

  def airbrake_severity(severity)
    (case severity
     when DEBUG
       'debug'
     when INFO
       'info'
     when WARN
       'warning'
     when ERROR, UNKNOWN
       'error'
     when FATAL
       'critical'
     end).freeze
  end
end
