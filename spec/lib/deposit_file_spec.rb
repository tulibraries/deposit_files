require 'deposit_file'
require 'pry-remote'

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
    let (:email) { "fred@example.com" }

    it "Is a valid manifest file" do
      expect(manifest.drivename).to eq drivename
      expect(manifest.destination).to eq destination
      expect(manifest.share).to eq share
      expect(manifest.name).to eq name
      expect(manifest.email).to eq email
    end
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

  context "Read config file" do

    it "has expected default values" do
      config = YAML.load_file(File.expand_path("../../../config/deposit_files.yml.example", __FILE__))
      expect(config["email_sender"]).to eq "from@example.com"
      expect(config["email_admin_recipient"]).to match "to@example.com"
      expect(config["email_delivery_method"]).to eq :sendmail
    end
  end

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

  context "creates remote files" do

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

  context "Problem file" do
    let (:problems) {
      [{ :local_path => 'pictures/image1.jpg', :error => 'missing' },
       { :local_path => 'pictures/image2.jpg', :error => 'mismatch', :local_checksum => '953056255457fec9de753e4e698a72b7', :remote_checksum => '3c9b22c5a405b6cd074df94b879148f5' } ]
    }

    it "reads problem files" do
      problems_read = FileQA::read_problems_file("spec/fixtures/problem/problems.txt")
      expect(problems_read.count).to eq 2
      expect(problems_read.first[:local_path]).to eq problems.first[:local_path]
      expect(problems_read.first[:error]).to eq problems.first[:error]
      expect(problems_read.last[:local_path]).to eq problems.last[:local_path]
      expect(problems_read.last[:error]).to eq problems.last[:error]
      expect(problems_read.last[:local_checksum]).to eq problems.last[:local_checksum]
      expect(problems_read.last[:remote_checksum]).to eq problems.last[:remote_checksum]
    end

    it "creates problem file" do
      problems_file = FileQA::create_problems_file(problems, collection_drivename, collection_name)
      problems_read = FileQA::read_problems_file(problems_file)
      expect(problems_read.count).to eq 2
      expect(problems_read.first[:local_path]).to eq problems.first[:local_path]
      expect(problems_read.first[:error]).to eq problems.first[:error]
      expect(problems_read.last[:local_path]).to eq problems.last[:local_path]
      expect(problems_read.last[:error]).to eq problems.last[:error]
      expect(problems_read.last[:local_checksum]).to eq problems.last[:local_checksum]
      expect(problems_read.last[:remote_checksum]).to eq problems.last[:remote_checksum]
    end

  end

  context "QA operation" do
    it "detects matching local and remote checksum file" do
      FileQA::create_remote_checksums_file(collection_drivename, collection_name, remote_checksum_file)
      expect { FileQA::verify_file_upload(collection_drivename, collection_name) }.to_not raise_error
    end

    it "detects non-matching local and remote checksum file" do
      FileUtils.cp "spec/fixtures/alternate/pictures/image2.jpg", "tmp/kittens/pictures/image2.jpg"
      FileQA::create_remote_checksums_file(collection_drivename, collection_name, remote_checksum_file)
      problems = FileQA::verify_file_upload(collection_drivename, collection_name)
      expect(problems.first).to include(:error => "mismatch")
    end

    it "detects missing remote file" do
      FileUtils.rm "tmp/kittens/pictures/image2.jpg"
      FileQA::create_remote_checksums_file(collection_drivename, collection_name, remote_checksum_file)
      problems = FileQA::verify_file_upload(collection_drivename, collection_name)
      expect(problems.first).to include(:error => "missing")
    end

  end

  context "Notifier" do

    Mail.defaults do
      delivery_method :test # in practice you'd do this in spec_helper.rb
    end

    describe "sending an email" do

      before(:each) do
        Mail::TestMailer.deliveries.clear

        Mail.deliver do
          to ['mikel@me.com', 'mike2@me.com']
          from 'you@you.com'
          subject 'testing'
          body 'hello'
        end
      end

      it "should deliver" do
        deliveries = Mail::TestMailer.deliveries
        expect(deliveries.last.body.raw_source).to eq "hello"
      end

      it "should have hello" do
        deliveries = Mail::TestMailer.deliveries
        expect(deliveries.length).to eq 1
        expect(deliveries.last.body.raw_source).to eq "hello"
      end

      it "sends a upload successful message"
      it "sends a upload mismatch message"
      it "sends a upload file missing message"
      it "sends a upload complete message"
    end


  end
end
