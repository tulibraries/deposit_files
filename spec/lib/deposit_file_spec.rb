require 'deposit_file'

RSpec.describe Manifest do
  context "Read Manifest" do
    let (:manifest) { Manifest.new("spec/fixtures/kittens/admin/manifest.txt") }
    let (:drivename) { "spec/fixtures" }
    let (:destination) { "cats" }
    let (:share) { "deposit" }
    let (:name) { "kittens" }
    let (:email) { "steven.ng@temple.edu" }

    it "Is a valid manifest file" do
      expect(manifest.drivename).to eq drivename
      expect(manifest.destination).to eq destination
      expect(manifest.share).to eq share
      expect(manifest.name).to eq name
      expect(manifest.email).to eq email
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

RSpec.describe FileQA do
  let (:expected_checksums) {
        ["535e9c1fff0d2068d24b468103f95107",
         "953056255457fec9de753e4e698a72b7",
         "4e95a8c5dfaaf93b8f10115f6d694efc" ]}

  context "Reads checksum file" do
    let (:file_checksums) { FileQA::read("spec/fixtures/kittens/admin/checksum.txt") }

    it "has valid data" do
      expect(file_checksums.count).to eq 3
      file_checksums.each_with_index do |f, index|
        expect(f[:path]).to eq "pictures/image#{index+1}.jpg"
        expect(f[:checksum]).to eq expected_checksums[index]
      end
    end
  end

  context "creates remote checksum files" do
    let (:collection_drivename) { "#{Dir.pwd}/spec/fixtures" }
    let (:collection_name) { "kittens" }
    let (:remote_checksum_file) {"tmp/checksums.txt"}

    it "calculates checksums of files in remote" do
      file_checksums = FileQA::calculate_remote_checksums(collection_drivename, collection_name)
      expect(file_checksums.count).to eq 3
      file_checksums.each_with_index do |f, index|
        expect(f[:path]).to eq "pictures/image#{index+1}.jpg"
        expect(f[:checksum]).to eq expected_checksums[index]
      end
    end

    it "creates a checksum file" do
      FileQA::create_remote_checksums_file(collection_drivename, collection_name, remote_checksum_file)
      file_checksums = FileQA::read(remote_checksum_file)
      expect(file_checksums.count).to eq 3
      file_checksums.each_with_index do |f, index|
        expect(f[:path]).to eq "pictures/image#{index+1}.jpg"
        expect(f[:checksum]).to eq expected_checksums[index]
      end
    end
  end
end
