require 'deposit_file'

RSpec.describe Manifest do
  before (:each) do
    FileUtils.cp_r "spec/fixtures/kittens", "tmp"
  end


  after (:each) do
    FileUtils.rm_r "tmp/kittens"
  end

  context "Read Manifest" do
    let (:manifest) { Manifest.new("tmp/kittens/admin/manifest.txt") }
    let (:drivename) { "tmp" }
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

  context "Notification" do
    it "sends a successful match message"
    it "sends a unsuccessful match message"
    it "sends a file missing message"
    it "sends a successful sync message"
  end

  context "Sync files" do
    let (:expected_origin) { "tmp/kittens" }
    let (:expected_destination) { "tmp/deposit/cats/kittens" }
    it "successfully sync the file"
    it "fails to sync the file"
  end
end

RSpec.describe FileQA do
  before (:each) do
    FileUtils.cp_r "spec/fixtures/kittens", "tmp"
  end

  after (:each) do
    FileUtils.rm_r "tmp/kittens"
  end

  let (:collection_drivename) { "#{Dir.pwd}/tmp" }
  let (:collection_name) { "kittens" }
  let (:remote_checksum_file) {"tmp/kittens/admin/checksum_remote.txt"}

  let (:expected_checksums) {
        ["535e9c1fff0d2068d24b468103f95107",
         "953056255457fec9de753e4e698a72b7",
         "4e95a8c5dfaaf93b8f10115f6d694efc" ]}

  context "Reads checksum file" do
    let (:local_file_checksums) { FileQA::read_checksums("tmp/kittens/admin/checksum.txt") }

    it "has valid data" do
      expect(local_file_checksums.count).to eq 3
      local_file_checksums.keys.each_with_index do |path, index|
        expect(path).to eq "pictures/image#{index+1}.jpg"
        expect(local_file_checksums[path]).to eq expected_checksums[index]
      end
    end
  end

  context "creates remote checksum files" do

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
      file_checksums = FileQA::read_checksums(remote_checksum_file)
      expect(file_checksums.count).to eq 3
      file_checksums.keys.each_with_index do |path, index|
        expect(path).to eq "pictures/image#{index+1}.jpg"
        expect(file_checksums[path]).to eq expected_checksums[index]
      end
    end
  end

  context "QA files" do
    before (:each) do
      FileQA::create_remote_checksums_file(collection_drivename, collection_name, remote_checksum_file)
    end

    it "detects matching local and remote checksum file" do
      expect { FileQA::verify_file_upload(collection_drivename, collection_name) }.to_not raise_error
    end

    xit "detects non-matching local and remote checksum file" do
      expect { FileQA::verify_file_upload(collection_drivename, collection_name) }.to raise_error(FileQA::FileMismatchError)
    end

    xit "detects missing remote file" do
      expect { FileQA::verify_file_upload(collection_drivename, collection_name) }.to raise_error(FileMissingError)
    end
  end
end
