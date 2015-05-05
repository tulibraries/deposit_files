require 'CSV'
require 'Digest'

class Manifest
  attr_reader :drivename, :destination, :share, :name, :email

  def initialize(manifest_path)
    @manifest_file = File.open(manifest_path)
    @drivename = @manifest_file.readline.rstrip
    @destination = @manifest_file.readline.rstrip
    @share = @manifest_file.readline.rstrip
    @name = @manifest_file.readline.rstrip
    @email = @manifest_file.readline.rstrip
  end
end

module FileQA

  def self.read(checksum_path)
    checksums = Array.new
    CSV.foreach(checksum_path, :col_sep => '|').each do |row|
      checksums << { :path => row[0], :checksum => row[1] }
    end
    checksums
  end

  def self.exclude_directory(directory)
    excluded_directories = [".", "..", "admin"]
    found = excluded_directories.select { |d| d =~ /#{directory}/ }
    found.count != 0
  end

  def self.full_path(drivename, collection_name, directory)
    "#{drivename}/#{collection_name}/#{directory}"
  end

  def self.calculate_remote_checksums(drivename, collection_name)
    checksums = Array.new
    root_path = "#{drivename}/#{collection_name}"

    # Get the files for the subdirectories

    u_directories = Dir.entries(root_path).select { |fn| File.directory?("#{root_path}/#{fn}") && !exclude_directory(fn)  }

    # For each subdirectory, get the name of the file it contains
    u_directories.each do |directory|
      directory_path = full_path(drivename, collection_name, directory)
      files = Dir.entries(directory_path).select { |fn| !File.directory?(fn) }
      files.each do |file|
        checksum = Digest::MD5.file("#{directory_path}/#{file}").hexdigest
        checksums << { :path => "#{directory}/#{file}", :checksum => checksum }
      end
    end

    return checksums
  end

  def self.create_remote_checksums_file(drivename, collection_name, remote_checksums_file)
    checksums = calculate_remote_checksums(drivename, collection_name)
    CSV.open(remote_checksums_file, "w", :col_sep => '|') do |csv|
      checksums.each do |row|
        csv << [row[:path],row[:checksum]]
      end
    end
  end
end
