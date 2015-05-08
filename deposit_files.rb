require_relative 'lib/deposit_file'

Mail.defaults do
  delivery_method :sendmail
end

config = YAML.load_file(File.expand_path("config/deposit_files.yml"))
manifest = Manifest.new(File.expand_path("tmp/kittens/admin/manifest.txt"))
remote_checksum_file = "#{manifest.drivename}/#{manifest.name}/admin/checksum-remote.txt"

FileQA::create_remote_checksums_file(manifest.drivename, manifest.name, remote_checksum_file)
problems = FileQA::verify_file_upload(manifest.drivename, manifest.name)
FileQA::notify(manifest.drivename, manifest.name)
if problems.empty?
  sync_success = FileQA::sync(manifest.drivename, manifest.share, manifest.destination, manifest.name)
  FileQA::notify_complete
end
