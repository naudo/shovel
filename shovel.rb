require 'rubygems'
require 'bundler/setup'
require 'fog'


# Ugh, this won't work with ruby 2.2.0 and openssl 1.0.2
# On a Mac, downgrade OpenSSL to 1.0.1j
# brew uninstall openssl
# cd /usr/local # Homebrew git repo
# git checkout ae4251d9c179140207399de6ddcc7fb789763933 # Homebrew support for 1.0.1
# brew install openssl
# git checkout master
# The above commands will let you download an older verion of openssl
# brew info will show what version of openssl you have installed, but ruby may have been compiled against something older.
# Check the version you're running on ruby via ruby -ropenssl -e 'puts OpenSSL::OPENSSL_VERSION'
# rbenv uninstall 2.2.1 && rbenv install 2.2.1
# as always, installing a new version of ruby (or reinstalling means rebundling )
# gem install bundler && bundle install
S3_BUCKET_BASE = 'hb-video-store-'
VIDEO_STORE_ENV = ENV['VIDEO_STORE_ENV'] || 'development'
S3_BUCKET = S3_BUCKET_BASE + VIDEO_STORE_ENV
object_name = 'oop.mp4'
bucket_name = S3_BUCKET
# requires us to split videos into 5 MB chunks (amazon requirement)
# split -b 5m oop.mp4 oop.mp4.
# http://docs.amazonwebservices.com/AmazonS3/latest/dev/qfacts.html
parts = Dir.glob('videos/oop.mp4.*').sort

storage = Fog::Storage.new(
  provider: 'AWS',
  aws_access_key_id: ENV['AWS_ACCESS_KEY'],
  aws_secret_access_key: ENV['SECRET_AWS_ACCESS_KEY'],
  region: 'us-west-1'

)
puts 'Pending Multipart uploads'
response = storage.list_multipart_uploads (S3_BUCKET)

puts response.inspect, '\n\n'


puts 'Initiating multipart uploads'
response = storage.initiate_multipart_upload bucket_name, object_name
upload_id = response.body['UploadId']
puts "Upload ID: #{upload_id}"

# We could retrive the list of already uploaded parts via list_parts(), but
# it's better to do our homeworks and skip a request to AWS.
part_ids = []

parts.each_with_index do |part, position|
  part_number = (position + 1).to_s
  puts "Uploading #{part}"
  File.open part do |part_file|
    response = storage.upload_part bucket_name, object_name, upload_id,
      part_number, part_file
    part_ids << response.headers['ETag']
  end
end

puts "Parts' ETags: #{part_ids.inspect}", "\n\n"

puts 'Pending multipart uploads'
response = storage.list_multipart_uploads bucket_name
puts response.inspect, "\n\n"

puts 'Completing multipart upload'
response = storage.complete_multipart_upload bucket_name, object_name,
  upload_id, part_ids
puts response.inspect, "\n\n"

puts 'Pending multipart uploads'
response = storage.list_multipart_uploads bucket_name
puts response.inspect, "\n\n"

puts 'Checking the uploaded object'
response = storage.directories.get(bucket_name).files.get(object_name)
puts response.inspect, "\n\n"
