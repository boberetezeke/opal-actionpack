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

        opts.on("-g", "--development-gem", "add from development gem") do
          @options[:add_from_gem] = true
          @options[:development_gem] = true
        end
        
        opts.on("-G", "--production-gem", "add from production gem") do
          @options[:add_from_gem] = true
          @options[:production_gem] = true
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

  def link_files(root, use_absolute_path)
    files = flatten(@filenames).reject do |filename|
      File.exist?(linked_filename(root, filename))
    end
    
    files.each do |filename|
      if @options[:verbose_mode]
        puts "will link: #{linked_filename(root, filename)} to #{filename}"
      end
    end

    if @options[:verbose_mode]
      puts "press return key to run"
      $stdin.gets
    end

    files.each do |filename|
      if @options[:verbose_mode]
        puts "linking: #{linked_filename(root, filename)} to #{filename}"
      end
      link_file(filename, linked_filename(root, filename), use_absolute_path)
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
      if @options[:add_from_gem]
        if @filenames.size != 1
          puts "only one gem allowed per invocation" 
          exit 1
        end

        root = get_gem_root

        if @options[:development_gem]
          if m = /^#{Dir.pwd}\/(.*)$/.match(root)
            root = m[1] 
          else
            common_segments, unique_segments = split_root(root, Dir.pwd)
            pwd_segments = Dir.pwd.split(/\//)
            back_out_segments_size = pwd_segments.size - common_segments.size
            root = Array.new(back_out_segments_size, "..").join("/") + "/" + unique_segments.join("/")
          end
        end

        puts "root = #{root}"
        @filenames = ["#{root}/app"]
      else
        root = "."
      end

      if @options[:check_files]
        check_files
      else
        link_files(root, !@options[:production_gem].nil?)
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

  
  def get_gem_root
    run_filename = "__get_gem_path.sh"
    File.open(run_filename, "w") { |f| f.write "bundle show #{@filenames.first}" }
    # root = `bundle show #{@filenames}`.chomp
    root = `bash #{run_filename}`.chomp
    File.unlink(run_filename)

    root
  end

  #
  # Split the root into two sets of path segments:
  # * the first are in common
  # * the second are the segments not in common
  #
  # @param root [String] the root path of the gem
  # @param pwd [String] the current directory of this project
  # @returns Array(Array<String>, Array<String>)
  #
  def split_root(root, pwd)
    root_segments = root.split(/\//)
    pwd_segments =  pwd.split(/\//)
    mismatch_index = 0
    root_segments.zip(pwd_segments).each_with_index do |(root_seg, pwd_seg), index|
      if root_seg != pwd_seg
        mismatch_index = index
        break
      end
    end

    [root_segments[0..mismatch_index-1], root_segments[mismatch_index..-1]]
  end

  def linked_filename(root, filename)
    javascript_root = "app/assets/javascripts/opal"
    if    m = /app\/(.*)\.html\.haml$/.match(filename)
      "#{javascript_root}/#{m[1]}.haml" 
    elsif m = /app\/(.*)\.rb$/.match(filename)
      "#{javascript_root}/#{m[1]}.js.rb" 
    else
      raise "can't link filename: #{filename}"
    end
  end

  def link_file(filename, linked_filename, use_absolute_path)
    if use_absolute_path
      if @options[:verbose_mode]
        puts "link from #{linked_filename}"
        puts "     to   (absolute) #{filename}"
      end
      File.symlink(filename, linked_filename)
    else
      linked_parts = linked_filename.split(/\//)
      (linked_parts.size-1).times do |index|
        partial_path = linked_parts[0..index].join("/")
        if !FileTest.directory?(partial_path)
          if @options[:verbose_mode]
            puts "creating directory: #{partial_path}"
          end
          Dir.mkdir(partial_path)
        else
          if @options[:verbose_mode]
          #  puts "directory exists: #{partial_path}"
          end
        end
      end

      source_filename = ([".."] * (linked_parts.size-1)).join("/") + "/" + filename
      puts "source_filename = #{source_filename}"
      if @options[:verbose_mode]
        full_source_filename = nil
        Dir.chdir(linked_filename.split(/\//)[0..-2].join("/")) do
          full_source_filename = File.expand_path(source_filename)
        end
        puts "link from #{linked_filename}"
        puts "     to   (relative) #{source_filename}"
        puts "          (full)     #{full_source_filename}"
      end
      
      File.symlink(source_filename, linked_filename)
    end
  end
end

CommandRunner.new.process_filenames
