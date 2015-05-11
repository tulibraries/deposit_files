require_relative 'lib/deposit_file'

Mail.defaults do
  delivery_method :sendmail
end

config = YAML.load_file(File.expand_path("config/deposit_files.yml"))
manifest = FileQA::Manifest.new(File.expand_path("tmp/deposit_temp/kittens/admin/manifest.txt"))
remote_checksum_file = "#{manifest.drivename}/deposit_temp/#{manifest.name}/admin/checksum-remote.txt"

FileQA::create_remote_checksums_file(manifest.drivename, manifest.name, remote_checksum_file)
problems = FileQA::verify_file_upload(manifest.drivename, manifest.name)
FileQA::notify(manifest)
if problems.empty?
  sync_success = FileQA::sync(manifest)
  FileQA::notify_complete(manifest)
end
