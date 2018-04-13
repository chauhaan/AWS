#This script will create a key pair and download private key in the user's download folder.
#Deploy Amazon Linux instances in two different availability zones of a region.
#Import the self signed certificate to Amazaon Certificate Manager.
#Create one DB instance on RDS.
#Create Elastic Load Balancer and add web application instances to it.
Write-Host "`n"
Write-Host "## Starting Process ##"
Write-Host "`n"
#Import AWS module in powershell
Import-Module AWSPowerShell


#Give the AWS access and secret key for the credential access
$AccessKey = Read-Host "Please enter your Access key"
Write-Host "`n"
$SecretKey = Read-Host "Please enter your Secret key"
Set-AWSCredential -AccessKey $AccessKey -SecretKey $SecretKey
Write-Host "`n"


#Select the AWS region for the deployment
Write-Host "## AWS Region ##"
$AWSRegion = Get-AWSRegion
$Region = @()
for ($i=0; $i -lt $AWSRegion.length; $i++)
{
    $object = New-Object PSObject -Property @{
    SerialNumber = $i+1
    AWSRegion = $AWSRegion[$i].Name }
    $Region += $object
}
$Region | Format-Table SerialNumber,AWSRegion
[int]$item = Read-Host "Please select AWS region for deployment - Enter SerialNumber"
Write-Host
while ( !($item -ge 1 -and $item -le $AWSRegion.Length) ) {
Write-Host
$item = Read-Host "Please enter correct SerialNumber for AWS region"
}
for ($i=1; $i -le $AWSRegion.Length; $i++) {
Switch ($item)
      {
       $i { $Region_ID=$AWSRegion[$item-1].Region }
      }
  }
Set-DefaultAWSRegion -Region $Region_ID
Write-Host "`n"


#Select the VPC
Write-Host "## VPC ##"
$VPC = Get-EC2Vpc
$VPC_1 = @()
for ($i=0; $i -lt $VPC.length; $i++)
{
    $object = New-Object PSObject -Property @{
    SerialNumber = $i+1
    VPC = $VPC[$i].VpcId }
    $VPC_1 += $object
}
$VPC_1 | Format-Table SerialNumber,VPC
[int]$item = Read-Host "Please select the VPC - Enter SerialNumber"
Write-Host
while ( !($item -ge 1 -and $item -le $VPC.length) ) {
Write-Host
$item = Read-Host "Please enter correct SerialNumber for VPC"
}
for ($i=1; $i -le $VPC.Length; $i++){
Switch ($item)
      { 
       $i { $VPC_ID=$VPC[$item-1].VpcId }
      }
  }
Write-Host "`n"


#It create a key pair for the instances
Write-Host "## Key Generation ##"
Write-Host
$key = Read-Host "Please enter a key name to create a keypair and it will save the private key in your download folder"
$KeyPair = New-EC2KeyPair -KeyName $key
$keypair.KeyMaterial | Out-File -FilePath "C:\Users\$env:USERNAME\Downloads\$key.pem" -Encoding ascii  
Write-Host
echo "Key has been downloaded in your download folder"
Write-Host
Write-Host "`n"


#It creates a database server on RDS for the webapplication
Write-Host "## DATABASE SERVER ##"
Write-Host "`n"
Write-Host "Creating a Database Server"
Write-Host "`n"
$DBInstance = New-RDSDBInstance -DBName blog -AllocatedStorage 20 -DBInstanceIdentifier "WebappDB" -DBInstanceClass "db.t2.micro" -Engine mariadb -MasterUsername root -MasterUserPassword "root12345"
Write-Host "Please wait until the database server is getting ready"
Write-Host
while(!((Get-RDSDBInstance -DBInstanceIdentifier $DBInstance.DBInstanceIdentifier).DBInstanceStatus -eq "available"))
{
    Write-Host -NoNewLine "."
    start-sleep -Seconds 5
}
Write-Host "`n"
$DBhost = (Get-RDSDBInstance -DBInstanceIdentifier $DBInstance.DBInstanceIdentifier).Endpoint.Address
Write-Host "Database server is created now"
Write-Host "`n"
Write-Host "`n"


# It create an Instances in two availability zones and deploy the web application on both instances
Write-Host "## WEBAPP SERVERS ##"
Write-Host "`n"
Write-Host "Creating WebApp Servers"
$script = "#!/bin/bash
sudo yum install httpd -y
sudo yum install php -y
sudo yum install php-mysql -y
sudo yum install git -y
sudo yum install mysql-server -y
sudo service mysqld restart
sudo yum install mod_ssl -y
sudo chkconfig httpd on --level 3
sudo chkconfig mysqld on --level 3
cd /home/ec2-user/
git clone https://github.com/chauhaan/AWS.git
cd /etc/httpd/conf.d/
sudo echo '<VirtualHost *:80>
     DocumentRoot /var/www/webapp
     DirectoryIndex index.php
</VirtualHost>' > webapp.conf
cd /home/ec2-user/
sudo echo '[mysql]
host=$DBhost
user=root
password=root12345
database=blog' > .my.cnf
cd /home/ec2-user/AWS
sudo unzip webapp.zip
sudo cp -r webapp /var/www/
sudo cp Certificate.crt /etc/pki/tls/certs/
sudo cp PrivateKey.key /etc/pki/tls/private/
sudo sed -i '187 a DocumentRoot /var/www/webapp' /etc/httpd/conf.d/ssl.conf
sudo sed -i '188 a DirectoryIndex index.php' /etc/httpd/conf.d/ssl.conf
sudo sed -i '106 c SSLCertificateFile /etc/pki/tls/certs/Certificate.crt' /etc/httpd/conf.d/ssl.conf
sudo sed -i '113 c SSLCertificateKeyFile /etc/pki/tls/private/PrivateKey.key' /etc/httpd/conf.d/ssl.conf
sudo chmod 777 /home/ec2-user/AWS/AddDBHost
sudo bash /home/ec2-user/AWS/AddDBHost $DBhost
sudo service httpd restart
"
$encodescript = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($script))
$AvailabilityZone = Get-EC2AvailabilityZone
$EC2subnet = Get-EC2Subnet
$instances = @()
for ($i=0; $i -lt $AvailabilityZone.Length; $i++)
{

    $EC2subnet_1 = $EC2subnet | Where-Object { $_.VpcId -eq $VPC_ID } | Where-Object { $_.AvailabilityZone -eq $AvailabilityZone[$i].ZoneName }
    $EC2subnet_2 = @()
    for ($j=0; $j -lt $EC2subnet_1.length; $j++)
    {
        $object = New-Object PSObject -Property @{
        SerialNumber = $j+1
        Subnet = $EC2subnet_1[$j].SubnetId }
        $EC2subnet_2 += $object
    }
    $EC2subnet_2 | Format-Table SerialNumber,Subnet
    [int]$item = Read-Host "Please select the subnet for the $($i+1) Instance deployment - Enter SerialNumber"
    Write-Host
    while ( !($item -ge 1 -and $item -le $EC2subnet_1.length) ) {
    Write-Host "`n"
    $item = Read-Host "Please enter correct serial number of subnet"
    }
    for ($k=1; $k -le $EC2subnet_1.length; $k++){
    Switch ($item)
        {
                $k { $subnet_ID=$EC2subnet_1[$item-1].SubnetId }
        }
    }

    $TagSpec = New-Object Amazon.EC2.Model.TagSpecification
    $Tag = New-Object Amazon.EC2.Model.Tag
    $Tag.Key = "Name"
    $Tag.Value = "Webapp$($i+1)"
    $TagSpec.Tags = $Tag
    $TagSpec.ResourceType = "Instance"
    $instance = New-EC2Instance -ImageId "ami-7c87d913" -MinCount 1 -MaxCount 1 -KeyName $key -InstanceType t2.micro -AvailabilityZone $AvailabilityZone[$i].ZoneName -SubnetId $subnet_ID -UserData $encodescript -TagSpecification $TagSpec
    $instances += $instance
}
Write-Host "`n"
Write-Host "Please wait until web servers getting ready"
Write-Host
while(!(((Get-EC2InstanceStatus -InstanceId "$($instances[0].Instances.InstanceId)").Status.Status.Value -eq "ok") -and ((Get-EC2InstanceStatus -InstanceId "$($instances[1].Instances.InstanceId)").Status.Status.Value -eq "ok")))
{
    Write-Host -NoNewLine "."
    start-sleep -Seconds 5
}
Write-Host "`n"
Write-Host "Web servers are ready now"
Write-Host "`n"
Write-Host "`n"


#Import the self signed certificate to Amazon certificate manager
$certificate_ACM = Get-Content ".\Certificate.pem" -Encoding Byte
$key_ACM = Get-Content ".\PrivateKey.pem" -Encoding Byte
$CertificateARN = Import-ACMCertificate -Certificate $certificate_ACM -PrivateKey $key_ACM

#create a load balancer and add instances to load balancer
Write-Host "## LOAD BALANCER ##"
Write-Host "`n"
Write-Host "Creating a Load Balancer"
Write-Host "`n"
$VPC_ID = $instances[0].Instances.VpcId
$TargetGroup1 = New-ELB2TargetGroup -HealthCheckIntervalSecond 300 -Name "WebApp-Https" -port 443 -Protocol https -VpcId $VPC_ID
$TargetGroup2 = New-ELB2TargetGroup -HealthCheckIntervalSecond 300 -Name "WebApp-Http" -port 80 -Protocol http -VpcId $VPC_ID
$target = @()
for ($i=0; $i -lt $instances.Length; $i++)
{
    $target += New-Object Amazon.ElasticLoadBalancingV2.Model.TargetDescription
    $target[$i].Id = $instances[$i].Instances.InstanceId
}
Register-ELB2Target -TargetGroupArn $TargetGroup1.TargetGroupArn -Target $target
Register-ELB2Target -TargetGroupArn $TargetGroup2.TargetGroupArn -Target $target
$ELBsubnet = @()
for ($i=0; $i -lt $instances.Length; $i++)
{
    $ELBsubnet += $instances[$i].Instances.SubnetId
}
$LoadBalancer = New-ELB2LoadBalancer -IpAddressType ipv4 -Name WebappLoadBalancer -Subnet $ELBsubnet
Write-Host "Please wait until load balancer getting ready"
Write-Host
while(!((Get-ELB2LoadBalancer -LoadBalancerArn "$($LoadBalancer.LoadBalancerArn)").State.Code.Value -eq "active"))
{
    Write-Host -NoNewLine "."
    start-sleep -Seconds 5
}
Write-Host "`n"
$Certificate_ELB = New-Object Amazon.ElasticLoadBalancingV2.Model.Certificate
$Certificate_ELB.CertificateArn = $CertificateARN
$Action_ELB1 = New-Object Amazon.ElasticLoadBalancingV2.Model.Action
$Action_ELB1.TargetGroupArn = $TargetGroup1.TargetGroupArn
$Action_ELB1.Type = "forward"
$Action_ELB2 = New-Object Amazon.ElasticLoadBalancingV2.Model.Action
$Action_ELB2.TargetGroupArn = $TargetGroup2.TargetGroupArn
$Action_ELB2.Type = "forward"
New-ELB2Listener -LoadBalancerArn "$($LoadBalancer.LoadBalancerArn)" -Port 443 -Protocol https -Certificate $Certificate_ELB -DefaultAction $Action_ELB1 > $null
New-ELB2Listener -LoadBalancerArn "$($LoadBalancer.LoadBalancerArn)" -Port 80 -Protocol http -DefaultAction $Action_ELB2 > $null
Write-Host "Please use the below DNS Name to access the web app"
Write-Host "`n"
Write-Host "################"
Write-Host "`n"
($LoadBalancer).DNSName
Write-Host "`n"
Write-Host "################"
Write-Host
Read-Host "Process is complete and press Enter to exit"