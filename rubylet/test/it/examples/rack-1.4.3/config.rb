puts "LOADING CONFIG"
data_source('jdbc/scholar',
            :driver_class => 'org.postgresql.Driver',
            :jdbc_url => 'jdbc:postgresql://localhost/cgplatform_dev',
            :user => 'cgplatform_dev',
            :password => 'JiaJee9xauJu',
            :min_pool_size => 2,
            :max_pool_size => 15)
