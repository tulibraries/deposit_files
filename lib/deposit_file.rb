require 'CSV'
require 'fileutils'
require 'mail'

module FileQA

  STAGING_DIR = "deposit-temp"
  ADMIN_DIR = "admin"
  MANIFEST_FILENAME = "manifest.txt"
  LOCAL_CHECKSUM_FILENAME = "checksum.txt"
  REMOTE_CHECKSUM_FILENAME = "checksum-remote.txt"
  PROBLEMS_FILENAME = "problems.txt"
  IGNORE_DIRS = [".", "..", "admin", '.DS_Store']

  class Manifest
    attr_reader :drivename, :destination, :share, :name, :email

    def initialize(root, deposit_directory)
      manifest_path = File.join(root, STAGING_DIR, deposit_directory, ADMIN_DIR, MANIFEST_FILENAME)
      @manifest_file = File.open(manifest_path)
      @drivename = @manifest_file.readline.rstrip
      @destination = @manifest_file.readline.rstrip
      @share = @manifest_file.readline.rstrip
      @name = @manifest_file.readline.rstrip
      @email = @manifest_file.readline.rstrip
    end
  end

  def self.get_deposits(root_path)
    staging_path = File.join(root_path, STAGING_DIR)
    deposits = Array.new
    Dir.entries(staging_path).each do |entry|
      deposits << entry if File.exist?(File.join(staging_path, entry, ADMIN_DIR, MANIFEST_FILENAME))
    end
    deposits
  end

  def self.read_checksums(checksum_path)
    checksums = Hash.new
    CSV.foreach(checksum_path, :col_sep => '|').each do |row|
      checksums[row[0]] = row[1]
    end
    checksums
  end

  # Recursively navigate all of the remote files,
  # Returns an array of the absolute path to the remote files
  def self.navigate_remote_files(root_path)
    files = Array.new
    Dir.entries(File.expand_path(root_path)).each do |entry|
      if !IGNORE_DIRS.include?(entry)
        file_path = File.join(root_path, entry)
        if Dir.exist?(file_path)
          files += navigate_remote_files(file_path)
        else
          files << file_path
        end
      end
    end
    files
  end

  # Get all of the remote files and strips off the root
  # Returns an array of the relative path to the remote files
  def self.get_remote_files(root_path)
    relative_file_paths = Array.new
    navigate_remote_files(root_path).each do |file_name|
      relative_file_paths << file_name.gsub(/^#{root_path}\//, '')
    end
    relative_file_paths
  end

  def self.calculate_remote_checksums(drivename, collection_name)
    checksums = Array.new
    root_path = File.join(drivename, STAGING_DIR, collection_name)

    # Get the files for the subdirectories

    transfer_files = get_remote_files(root_path)

    # Create the remote checksum files

    transfer_files.each do |file|
      checksum = Digest::MD5.file(File.join(root_path, file)).hexdigest
      checksums << { :path => file, :checksum => checksum }
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
    local_checksums = self.read_checksums(File.join(drivename, STAGING_DIR, collection_name, ADMIN_DIR, LOCAL_CHECKSUM_FILENAME))
    # Read remote checksum file
    remote_checksums = self.read_checksums(File.join(drivename, STAGING_DIR, collection_name, ADMIN_DIR, REMOTE_CHECKSUM_FILENAME))
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
    CSV.foreach(problems_file_path, :col_sep => '|', :headers => true).each do |row|
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
    problems_file_path = File.join(drivename, STAGING_DIR, collection_name, ADMIN_DIR, PROBLEMS_FILENAME)
    CSV.open(problems_file_path, "w", :col_sep => '|', :headers => true) do |csv|
      csv << ['path', 'error', 'local checksum', 'remote checksum']
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
    problems_file_dir = File.join(manifest.drivename, STAGING_DIR, manifest.name, ADMIN_DIR)
    config = YAML.load_file(File.expand_path("../../config/deposit_files.yml", __FILE__))
    mail = Mail.new do
      to [config['email_admin_recipient'],  manifest.email]
      from config['email_sender']
    end
    if Dir.entries(problems_file_dir).include? PROBLEMS_FILENAME
      mail.subject('File Problem Encountered')
      mail.add_file(File.join(problems_file_dir, PROBLEMS_FILENAME))
      if mismatch?(File.join(problems_file_dir, PROBLEMS_FILENAME))
        mail.add_file(File.join(problems_file_dir, LOCAL_CHECKSUM_FILENAME))
        mail.add_file(File.join(problems_file_dir, REMOTE_CHECKSUM_FILENAME))
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
    File.expand_path(File.join(manifest.drivename, STAGING_DIR, manifest.name))
  end

  def self.destination(manifest)
    File.expand_path(File.join(manifest.drivename, manifest.share, manifest.destination))
  end

  def self.sync(manifest)
    source = origin(manifest)
    target = destination(manifest)
    options = "-av"
    exclude = "--exclude=.DS_Store"

    unless (Dir.exist?(target))
      FileUtils.mkdir_p target
    end

    system "rsync", options, exclude, source, target
    s = ($?).to_s.split(" ")
    h = Hash[*s]
    h["exit"].to_i
  end

  def self.deposit_files(root, deposits)
    deposits.each do |deposit|
      manifest = FileQA::Manifest.new(root, deposit)
      config = YAML.load_file(File.expand_path("config/deposit_files.yml"))
      remote_checksum_file = File.join(manifest.drivename, STAGING_DIR, manifest.name, ADMIN_DIR, REMOTE_CHECKSUM_FILENAME)

      create_remote_checksums_file(manifest.drivename, manifest.name, remote_checksum_file)
      problems = verify_file_upload(manifest.drivename, manifest.name)
      notify(manifest)
      if problems.empty?
        sync_success = sync(manifest)
        notify_complete(manifest)
      end
    end
  end

end
