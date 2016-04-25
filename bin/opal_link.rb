#!/usr/bin/ruby
require 'optparse'

class CommandRunner
  USAGE = "#{File.basename($0)} [options] filenames..."

  def initialize
    @options = {
      verbose_mode: false
    }

    if ARGV.size == 0
      puts "USAGE: #{USAGE}"
      exit 1
    end

    begin
      OptionParser.new do |opts|
        opts.banner = USAGE + "\n\nRun command options\n\n"

        opts.on("-v", "--verbose", "verbose mode") do
          @options[:verbose_mode] = true
        end

        opts.on("-c", "--check", "check links") do
          @options[:check_files] = true
        end

        opts.on("-C", "--check-syntax", "check syntax") do
          @options[:check_files] = true
          @options[:check_syntax] = true
        end
      end.parse!
    rescue Exception => e
      puts "ERROR: #{e}"
      puts "USAGE: #{USAGE}"
      exit 1
    end
    
    @filenames = ARGV.dup
    self
  end

  def link_files
    files = flatten(@filenames).reject do |filename|
      File.exist?(linked_filename(filename))
    end
    
    files.each do |filename|
      if @options[:verbose_mode]
        puts "will link: #{linked_filename(filename)} to #{filename}"
      end
    end

    if @options[:verbose_mode]
      puts "press return key to run"
      $stdin.gets
    end

    files.each do |filename|
      if @options[:verbose_mode]
        puts "linking: #{linked_filename(filename)} to #{filename}"
      end
      link_file(filename, linked_filename(filename))
    end
  end

  def check_files
    files = flatten(@filenames)

    files.each do |filename|
      print "."; $stdout.flush
      if File.exist?(filename)
        if @options[:check_syntax]
          if    filename =~ /rb$/ &&  !system("ruby -c #{filename} > /dev/null")
              puts "#{filename}: invalid ruby syntax"
          elsif filename =~ /haml$/ &&  !system("haml --check #{filename} > /dev/null")
              puts "#{filename}: invalid haml syntax"
          end
        end
      else
        puts "#{filename}: not found"
      end
    end
    puts
  end

  def process_filenames
    begin
      if @options[:check_files]
        check_files
      else
        link_files
      end
    #rescue Exception => e
    #  puts "ERROR: #{e}"
    end
  end

  def flatten(filenames)
    return_filenames = []
    filenames.each do |filename|
      # remove trailing '/'
      if m = /^(.*)\/$/.match(filename)
        filename = m[1]
      end
      if FileTest.directory?(filename)
        return_filenames += flatten(Dir["#{filename}/*"])
      else
        if filename =~ /\.(haml|rb)$/
          return_filenames << filename
        end
      end
    end

    return_filenames
  end

  def linked_filename(filename)
    javascript_root = "app/assets/javascripts/opal"
    if    m = /^app\/(.*)\.html\.haml$/.match(filename)
      "#{javascript_root}/#{m[1]}.haml" 
    elsif m = /^app\/(.*)\.rb$/.match(filename)
      "#{javascript_root}/#{m[1]}.js.rb" 
    else
      raise "can't link filename: #{filename}"
    end
  end

  def link_file(filename, linked_filename)
    linked_parts = linked_filename.split(/\//)
    (linked_parts.size-1).times do |index|
      partial_path = linked_parts[0..index].join("/")
      if !FileTest.directory?(partial_path)
        if @options[:verbose_mode]
          puts "creating directory: #{partial_path}"
          Dir.mkdir(partial_path)
        end
      end
    end

    source_filename = ([".."] * (linked_parts.size-1)).join("/") + "/" + filename
    File.symlink(source_filename, linked_filename)
  end
end

CommandRunner.new.process_filenames
