-- Creates a sakai database at startup
create database sakai default character set utf8; 
grant all on sakai.* to sakai@'localhost' identified by 'ironchef'; 
grant all on sakai.* to sakai@'127.0.0.1' identified by 'ironchef';
grant all on sakai.* to sakai@'%' identified by 'ironchef';
