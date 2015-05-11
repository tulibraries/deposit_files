require 'deposit_file'
require 'pry-remote'

RSpec::Matchers.define :exist do
  match do |file_name|
    File.exist?(File.expand_path(file_name))
  end
end

RSpec.describe FileQA::Manifest do
  before (:each) do
    FileUtils.mkdir "tmp/deposit_temp"
    FileUtils.cp_r "spec/fixtures/kittens", "tmp/deposit_temp"
  end


  after (:each) do
    FileUtils.rm_r "tmp/deposit_temp"
  end

  context "Read Manifest" do
    let (:manifest) { FileQA::Manifest.new("tmp/deposit_temp/kittens/admin/manifest.txt") }
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

end

RSpec.describe FileQA do
  before (:each) do
    FileUtils.mkdir "tmp/deposit_temp"
    FileUtils.cp_r "spec/fixtures/kittens", "tmp/deposit_temp"
    FileUtils.mkdir "tmp/deposit"
  end

  after (:each) do
    FileUtils.rm_r "tmp/deposit_temp"
    FileUtils.rm_r "tmp/deposit"
  end

  let (:config) { YAML.load_file(File.expand_path("config/deposit_files.yml")) }
  let (:manifest) { FileQA::Manifest.new(File.expand_path("tmp/deposit_temp/kittens/admin/manifest.txt")) }

  let (:collection_drivename) { "#{Dir.pwd}/tmp" }
  let (:collection_destination) { "cats" }
  let (:collection_share) { "deposit" }
  let (:collection_name) { "kittens" }
  let (:remote_checksum_file) {"tmp/deposit_temp/kittens/admin/checksum-remote.txt"}
  let (:remote_checksum_file_name) {"checksum-remote.txt"}

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
    let (:local_file_checksums) { FileQA::read_checksums("tmp/deposit_temp/kittens/admin/checksum.txt") }

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
      FileUtils.cp "spec/fixtures/alternate/pictures/image2.jpg", "tmp/deposit_temp/kittens/pictures/image2.jpg"
      FileQA::create_remote_checksums_file(collection_drivename, collection_name, remote_checksum_file)
      problems = FileQA::verify_file_upload(collection_drivename, collection_name)
      expect(problems.first).to include(:error => "mismatch")
    end

    it "detects missing remote file" do
      FileUtils.rm "tmp/deposit_temp/kittens/pictures/image2.jpg"
      FileQA::create_remote_checksums_file(collection_drivename, collection_name, remote_checksum_file)
      problems = FileQA::verify_file_upload(collection_drivename, collection_name)
      expect(problems.first).to include(:error => "missing")
    end

  end

  context "Notifier" do

    before (:all) do
      Mail.defaults do
        delivery_method :test
      end
    end

    after (:each) do
      Mail::TestMailer.deliveries.clear
    end

    describe "sending an email" do

      it "sends a upload successful message" do
        FileQA::notify(manifest)
        last_email = Mail::TestMailer.deliveries.last
        expect(last_email.to).to include(manifest.email)
        expect(last_email.to).to include(config['email_admin_recipient'])
        expect(last_email.subject).to match /success/i
        expect(last_email.attachments).to be_empty
      end

      it "detects mismatch in problems file" do
        FileUtils.cp_r "spec/fixtures/problem/problems-file-mismatch.txt", "tmp/deposit_temp/kittens/admin/problems.txt"
        expect(FileQA::mismatch?("tmp/deposit_temp/kittens/admin/problems.txt")).to be
        expect(FileQA::missing?("tmp/deposit_temp/kittens/admin/problems.txt")).to_not be
      end

      it "detects missing in problems file" do
        FileUtils.cp_r "spec/fixtures/problem/problems-file-missing.txt", "tmp/deposit_temp/kittens/admin/problems.txt"
        expect(FileQA::missing?("tmp/deposit_temp/kittens/admin/problems.txt")).to be
        expect(FileQA::mismatch?("tmp/deposit_temp/kittens/admin/problems.txt")).to_not be
      end

      describe "Problem message" do

        it "has a problem file attached for file missing errors" do
          FileUtils.cp_r "spec/fixtures/problem/problems-file-missing.txt", "tmp/deposit_temp/kittens/admin/problems.txt"

          FileQA::notify(manifest)
          last_email = Mail::TestMailer.deliveries.last
          expect(last_email.to).to include(manifest.email)
          expect(last_email.to).to include(config['email_admin_recipient'])
          expect(last_email.subject).to match /problem/i

          attachments = last_email.attachments.map { |attachment| attachment.filename }
          expect(attachments).to include("problems.txt")
          expect(attachments).to_not include("checksums.txt")
          expect(attachments).to_not include("checksums-remote.txt")
        end

        it "has a checksum and problem file attached for mismatch errors" do
          FileUtils.cp_r "spec/fixtures/problem/problems-file-mismatch.txt", "tmp/deposit_temp/kittens/admin/problems.txt"
          FileUtils.cp_r "spec/fixtures/kittens/admin/checksum.txt", remote_checksum_file
          FileQA::notify(manifest)

          last_email = Mail::TestMailer.deliveries.last
          expect(last_email.to).to include(manifest.email)
          expect(last_email.to).to include(config['email_admin_recipient'])
          expect(last_email.subject).to match /problem/i

          attachments = last_email.attachments.map { |attachment| attachment.filename }
          expect(attachments).to include("problems.txt")
          expect(attachments).to include("checksum.txt")
          expect(attachments).to include("checksum-remote.txt")
        end

        it "has a checksum and problem file attached for missing and mismatch errors" do
          FileUtils.cp_r "spec/fixtures/problem/problems.txt", "tmp/deposit_temp/kittens/admin"
          FileUtils.cp_r "spec/fixtures/kittens/admin/checksum.txt", remote_checksum_file
          FileQA::notify(manifest)

          last_email = Mail::TestMailer.deliveries.last
          expect(last_email.to).to include(manifest.email)
          expect(last_email.to).to include(config['email_admin_recipient'])
          expect(last_email.subject).to match /problem/i

          attachments = last_email.attachments.map { |attachment| attachment.filename }
          expect(attachments).to include("problems.txt")
          expect(attachments).to include("checksum.txt")
          expect(attachments).to include("checksum-remote.txt")
        end
      end

      it "sends a upload complete message" do
        FileQA::notify_complete(manifest)
        last_email = Mail::TestMailer.deliveries.last
        expect(last_email.to).to include(manifest.email)
        expect(last_email.to).to include(config['email_admin_recipient'])
        expect(last_email.subject).to match /complete/i
        expect(last_email.attachments.count).to eq 0
      end
    end

  end

  context "Sync files" do
    let (:expected_origin) { File.expand_path("tmp/deposit_temp/kittens") }
    let (:expected_destination) { File.expand_path("tmp/deposit/cats") }

    it "generates a destination directory" do
      expect(FileQA::destination(manifest)).to match "#{expected_destination}"
    end

    it "generates a origin directory" do
      expect(FileQA::origin(manifest)).to match "#{expected_origin}"
    end

    it "successfully sync the file" do
      expect(FileQA::sync(manifest)).to eq 0
    end

  end

  context "Functional Spec" do
    before (:all) do
      Mail.defaults do
        delivery_method :test
      end
    end

    before (:each) do
      Mail::TestMailer.deliveries.clear
    end

    it "runs successfully end-to-end test" do
      FileQA::deposit_files(manifest)
      expect("tmp/deposit/cats/kittens/admin/manifest.txt").to exist
      first_email = Mail::TestMailer.deliveries.first
      expect(first_email.subject).to match /success/i
      last_email = Mail::TestMailer.deliveries.last
      expect(last_email.subject).to match /complete/i
    end

    it "fails to transfer files due to mismatch" do
      allow(FileQA).to receive(:create_remote_checksums_file).with(manifest.drivename, manifest.name, "tmp/deposit_temp/kittens/admin/checksum-remote.txt") do
        FileUtils.cp_r "spec/fixtures/problem/problems-file-mismatch.txt", "tmp/deposit_temp/kittens/admin/problems.txt"
        FileUtils.cp_r "spec/fixtures/problem/checksum-remote-mismatch.txt", "tmp/deposit_temp/kittens/admin/checksum-remote.txt"
      end

      FileQA::deposit_files(manifest)

      expect("tmp/deposit/cats/kittens/admin/manifest.txt").to_not exist
      first_email = Mail::TestMailer.deliveries.first
      expect(first_email.subject).to match /problem/i
      last_email = Mail::TestMailer.deliveries.last
      expect(last_email.subject).to_not match /complete/i
    end

    it "fails to transfer files due to missing file" do
      allow(FileQA).to receive(:create_remote_checksums_file).with(manifest.drivename, manifest.name, "tmp/deposit_temp/kittens/admin/checksum-remote.txt") do
        FileUtils.cp_r "spec/fixtures/problem/problems-file-missing.txt", "tmp/deposit_temp/kittens/admin/problems.txt"
        FileUtils.cp_r "spec/fixtures/problem/checksum-remote-missing.txt", "tmp/deposit_temp/kittens/admin/checksum-remote.txt"
      end

      FileQA::deposit_files(manifest)

      expect("tmp/deposit/cats/kittens/admin/manifest.txt").to_not exist
      first_email = Mail::TestMailer.deliveries.first
      expect(first_email.subject).to match /problem/i
      last_email = Mail::TestMailer.deliveries.last
      expect(last_email.subject).to_not match /complete/i
    end
  end

end
