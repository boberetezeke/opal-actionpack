
class Template
  def self.current_output_buffer
    #puts "in self.current_output_buffer: (#{@output_buffer_stack.size})"
    @output_buffer
  end

  def self.current_output_buffer=(output_buffer)
    @output_buffer_stack ||= []
    @output_buffer_stack.push(@output_buffer) 
    @output_buffer = output_buffer
  end

  def self.output_buffer_stack
    @output_buffer_stack ||= []
  end

  def self.pop_output_buffer
    @output_buffer = @output_buffer_stack.pop
  end

  def render(ctx = self)
    self.class.current_output_buffer = OutputBuffer.new(self.class.output_buffer_stack.size)
    result = ctx.instance_exec(self.class.current_output_buffer, &@body)
    # puts "Template#render = #{result}"
    self.class.pop_output_buffer
    result
  end

  class OutputBuffer
    def initialize(id)
      @id = id
      @buffer_id = 0
      # puts "#{self}: initialize: #{@buffer.inspect}"
      @buffer_stack = []
      @buffer = []
      @attributes={}
    end

    def push_buffer
      # puts "#{self}: pushing buffer: #{@buffer.inspect}"
      @buffer_id += 1
      @buffer_stack.push(@buffer)
      # puts "#{self}: pushing to buffer stack: #{@buffer_stack.inspect}"
      @buffer = []
    end

    def pop_buffer
      # puts "#{self}: popping buffer: #{@buffer.inspect}"
      # puts "#{self}: popping buffer stack: #{@buffer_stack.inspect}"
      @buffer_id -= 1
      @buffer = @buffer_stack.pop
      # puts "#{self}: after popping buffer: #{@buffer.inspect}"
    end

    def append(str)
      # puts "#{self}: append: #{str.inspect}"
      # puts "append: #{caller[0..5]}"
      @buffer << str
    end

    def to_s
      "OutputBuffer(#{self.object_id}, #{@id}, #{@buffer_id})"
    end

    def attributes(*args)
      #puts "**** getting attributes: #{@attributes}, args= #{args}"
      # for some reason haml sometimes passes in the attributes it wants set on a tag as 
      # individual hashes one for each attribute and some arguments nil
      " " + args.reject{|a| a.nil?}.map{|a| "#{a.keys.first}=\"#{a.values.first}\"" }.join(" ")
    end

    alias append= append

    def join
      @buffer.each do |buf|
        #puts "-- #{self}: join: #{buf}"
      end
      # puts "#{self}: join: #{@buffer.join.inspect}"
      @buffer.join
    end
  end
end
