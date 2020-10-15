-- create data for bdc
create user test with ENCRYPTED  password '123456';
create database test owner test;

create table test
(
    id int primary key,
    name varchar(255) unique,
    age int not null ,
    address varchar(255)
);

Insert into test values(2, 'wxdlong2',30,'ShangeHai');