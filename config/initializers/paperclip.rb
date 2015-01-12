### s3 setting
#Paperclip::Attachment.default_options[:url] = ':s3_domain_url'
#Paperclip::Attachment.default_options[:path] = '/:class/:attachment/:id_partition/:style/:filename'

### local storage setting
Paperclip::Attachment.default_options[:url] = '/:class/:attachment/:id_partition/:filename'
Paperclip::Attachment.default_options[:path] = ':rails_root/public/:class/:attachment/:id_partition/:filename'

### example for url string
#without s3_domain_url: /system/file_uploads/files/000/000/050/original/67fb6c6c937e4400b15bdd6c813fa4ac.csv?1418121615
# with s3_domain_url: http://localhost:3000/courses/13/missions/21/:s3_domain_url?1418121615