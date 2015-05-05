class Manifest
  attr_reader :drivename, :destination, :share, :name, :email

  def initialize (manifest_path)
    @manifest_file = File.open(manifest_path)
    @drivename = @manifest_file.readline.rstrip
    @destination = @manifest_file.readline.rstrip
    @share = @manifest_file.readline.rstrip
    @name = @manifest_file.readline.rstrip
    @email = @manifest_file.readline.rstrip
  end
end

class Checksum
  attr_reader :checksums
end
