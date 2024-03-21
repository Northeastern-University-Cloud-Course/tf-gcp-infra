DB_HOST=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/db_host" -H "Metadata-Flavor: Google")
DB_USER=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/db_user" -H "Metadata-Flavor: Google")
DB_PASSWORD=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/db_password" -H "Metadata-Flavor: Google")

# Create application.properties at /tmp 
cat << EOF > /tmp/application.properties 
server.port=8080
spring.datasource.url=jdbc:mysql://${DB_HOST}:3306/webapp?createDatabaseIfNotExist=true
spring.datasource.username=${DB_USER}
spring.datasource.password=${DB_PASSWORD}
spring.jpa.hibernate.ddl-auto=create-drop
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.MySQL8Dialect
spring.jpa.show-sql=true
logging.file.path=./
EOF