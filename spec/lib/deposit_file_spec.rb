require 'deposit_file'

RSpec.describe Manifest do
  context "Read Manifest" do
    let (:manifest) { Manifest.new ("spec/fixtures/manifest.txt") }

    it "Is a valid manifest file" do
      expect(manifest.drivename).to eq "//CatsInc"
      expect(manifest.destination).to eq "tmp/cats"
      expect(manifest.share).to eq "tmp/deposit"
      expect(manifest.name).to eq "kittens"
      expect(manifest.email).to eq "steven.ng@temple.edu"
    end
  end

  context "QA files" do
    it "detects matching local and remote checksum file"
    it "detects non-matching local and remote checksum file"
    it "detects missing remote file"
  end

  context "Notification" do
    it "sends a successful match message"
    it "sends a unsuccessful match message"
    it "sends a file missing message"
    it "sends a successful sync message"
  end

  context "Sync files" do
    it "successfully sync the file"
    it "fails to sync the file"
  end
end

RSpec.describe Checksum do
  context "Read checksum file" do
    it "reads the file"
    it "parses creates a file/checksum array"
  end

  context "create checksum files" do
    it "calculates a file's checksum"
    it "creates a checksum file"
  end
end
