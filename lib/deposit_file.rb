require 'CSV'
require 'fileutils'
require 'mail'

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

  attr_reader :problems

  ADMIN_DIR = "admin"
  LOCAL_CHECKSUM_FILENAME = "checksum.txt"
  REMOTE_CHECKSUM_FILENAME = "checksum-remote.txt"
  PROBLEMS_FILENAME = "problems.txt"

  def self.read_checksums(checksum_path)
    checksums = Hash.new
    CSV.foreach(checksum_path, :col_sep => '|').each do |row|
      checksums[row[0]] = row[1]
    end
    checksums
  end

  def self.exclude_directory(directory)
    excluded_directories = [".", "..", "admin"]
    found = excluded_directories.select { |d| d =~ /#{directory}/ }
    found.count != 0
  end


  def self.calculate_remote_checksums(drivename, collection_name)
    checksums = Array.new
    root_path = "#{drivename}/#{collection_name}"

    # Get the files for the subdirectories

    u_directories = Dir.entries(root_path).select { |fn| File.directory?("#{root_path}/#{fn}") && !exclude_directory(fn)  }

    # For each subdirectory, get the name of the file it contains
    u_directories.each do |directory|
      directory_path = "#{drivename}/#{collection_name}/#{directory}"
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

  def self.verify_file_upload(drivename, collection_name)
    # Read local checksum file
    local_checksums = self.read_checksums("#{drivename}/#{collection_name}/#{ADMIN_DIR}/#{LOCAL_CHECKSUM_FILENAME}")
    # Read remote checksum file
    remote_checksums = self.read_checksums("#{drivename}/#{collection_name}/#{ADMIN_DIR}/#{REMOTE_CHECKSUM_FILENAME}")
    # Compare checksum file
    @problems = Array.new
    local_checksums.keys.each do |path|
      if (remote_checksums[path].nil?)
        @problems << { :local_path => path, :error => "missing" }
      elsif (local_checksums[path] != remote_checksums[path])
        @problems << { :local_path => path, :error => "mismatch", :local_checksum => local_checksums[path], :remote_checksum => remote_checksums[:path] }
      end
    end

    @problems
  end

  def self.read_problems_file(problems_file_path)
    problems = Array.new
    CSV.foreach(problems_file_path, :col_sep => '|').each do |row|
      problem = Hash.new
      problem[:local_path] = row[0]
      problem[:error] = row[1]
      problem[:local_checksum] = row[2] if row[2]
      problem[:remote_checksum] = row[3] if row[3]
      problems << problem
    end
    problems
  end

  def self.create_problems_file(problems, drivename, collection_name)
    problems_file_path = "#{drivename}/#{collection_name}/#{ADMIN_DIR}/#{PROBLEMS_FILENAME}"
    CSV.open(problems_file_path, "w", :col_sep => '|') do |csv|
      problems.each do |problem|
        row = Array.new
        row[0] = problem[:local_path]
        row[1] = problem[:error]
        row[2] = problem[:local_checksum] if problem[:local_checksum]
        row[3] = problem[:remote_checksum] if problem[:remote_checksum]
        csv << row
      end
    end
    problems_file_path
  end

  def self.mismatch?(problems_file_path)
    CSV.foreach(problems_file_path, :col_sep => '|').each do |row|
      if row[1] =~ /mismatch/i
        return true
      end
    end
    return false
  end

  def self.missing?(problems_file_path)
    CSV.foreach(problems_file_path, :col_sep => '|').each do |row|
      if row[1] =~ /missing/i
        return true
      end
    end
    return false
  end

  def self.notify(manifest)
    problems_file_dir = "#{manifest.drivename}/#{manifest.name}/#{ADMIN_DIR}"
    config = YAML.load_file(File.expand_path("../../config/deposit_files.yml", __FILE__))
    mail = Mail.new do
      to [config['email_admin_recipient'],  manifest.email]
      from config['email_sender']
    end
    if Dir.entries(problems_file_dir).include? PROBLEMS_FILENAME
      mail.subject('File Problem Encountered')
      mail.add_file("#{problems_file_dir}/#{PROBLEMS_FILENAME}")
      if mismatch?("#{problems_file_dir}/#{PROBLEMS_FILENAME}")
        mail.add_file("#{problems_file_dir}/#{LOCAL_CHECKSUM_FILENAME}")
        mail.add_file("#{problems_file_dir}/#{REMOTE_CHECKSUM_FILENAME}")
      end
    else
      mail.subject('File Uploaded Successfully')
    end
    mail.body "This is a test message"

    mail.deliver
  end

  def self.notify_complete(manifest)
    config = YAML.load_file(File.expand_path("../../config/deposit_files.yml", __FILE__))
    mail = Mail.new do
      to [config['email_admin_recipient'],  manifest.email]
      from config['email_sender']
      subject 'Deposit Complete'
      body 'The deposit completed successfully'
    end
    mail.deliver
  end

  def self.origin(manifest)
    File.expand_path(File.join(manifest.drivename, manifest.name))
  end

  def self.destination(manifest)
    File.expand_path(File.join(manifest.drivename, manifest.share, manifest.destination))
  end

  def self.sync(manifest)
    source = origin(manifest)
    target = destination(manifest)
    options = "-av"

    unless (Dir.exist?(target))
      FileUtils.mkdir_p target
    end

    system "rsync", options, source, target
    s = ($?).to_s.split(" ")
    h = Hash[*s]
    h["exit"].to_i
  end

  def self.deposit_files(manifest)
    config = YAML.load_file(File.expand_path("config/deposit_files.yml"))
    remote_checksum_file = "#{manifest.drivename}/#{manifest.name}/#{ADMIN_DIR}/#{REMOTE_CHECKSUM_FILENAME}"

    create_remote_checksums_file(manifest.drivename, manifest.name, remote_checksum_file)
    problems = verify_file_upload(manifest.drivename, manifest.name)
    notify(manifest)
    if problems.empty?
      sync_success = sync(manifest)
      notify_complete(manifest)
    end
  end

end
