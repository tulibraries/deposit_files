require 'deposit_file'

RSpec.describe Manifest do
  context "Read Manifest" do
    let (:manifest) { Manifest.new ("spec/fixtures/kittens/admin/manifest.txt") }

    it "Is a valid manifest file" do
      expect(manifest.drivename).to eq "spec/fixtures"
      expect(manifest.destination).to eq "cats"
      expect(manifest.share).to eq "deposit"
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
    let (:expected_origin) { "spec/fixtures/kittens" }
    let (:expected_destination) { "spec/fixtures/deposit/cats/kittens" }
    it "successfully sync the file"
    it "fails to sync the file"
  end
end

RSpec.describe Checksum do
  context "Read checksum file" do
    let (:checksum) { Checksum.new ("spec/fixtures/checksum.txt") }
    it "reads the file" do
      file_checksums = Array.new
      file_checksums = checksum.to_array
      expect(file_checksums.count).to eq 3
      expect(file_checksums[0].path).to eq "spec/fixtures/staging/image1.tif"
      expect(file_checksums[1].path).to eq "spec/fixtures/staging/image2.tif"
      expect(file_checksums[2].path).to eq "spec/fixutres/staging/image3.tif"
    end

    it "parses creates a file/checksum array"
  end

  context "create checksum files" do
    it "calculates a file's checksum"
    it "creates a checksum file"
  end
end
