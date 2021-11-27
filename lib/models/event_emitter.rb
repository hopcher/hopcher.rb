class EventEmitter
    @@listeners = Hash.new
    def initialize
    end

    def on(name, *func)
        @@listeners[name] ||= Array.new
        @@listeners[name] << func[0]
    end

    def emit(name, *args)
        return if !@@listeners.has_key?(name)
        @@listeners[name].each {|f| f.call(*args)}
    end
end