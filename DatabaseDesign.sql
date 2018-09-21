drop trigger at_least_reserves_one_table;
drop trigger at_least_has_one_order_item;
drop trigger table_capacity_restrict;
drop table menu cascade constraints;
drop table menu_item cascade constraints;
drop table menu_includes_menu_item cascade constraints;
drop table customer cascade constraints;
drop table booking cascade constraints;
drop table the_table cascade constraints;
drop table reserves cascade constraints;
drop table orders cascade constraints;
drop table order_item cascade constraints;

create table menu(
    name varchar(30) not null,
    menu_id integer,
    description varchar(500),
    constraint menu_pk primary key (menu_id));

create table menu_item(
    description varchar(500),
    name varchar(30) not null,
    menu_item_id integer,
    price numeric(5,2) not null,
    constraint menu_item_pk primary key (menu_item_id));
 
--The realation ship between menu and menu_item is many-to-many, so we should create a new table.   
create table menu_includes_menu_item(
    menu_id integer not null,
    menu_item_id integer not null,
    constraint menu_includes_menu_item_fk1 foreign key (menu_id) references menu on delete cascade deferrable initially deferred,
    constraint menu_includes_menu_item_fk2 foreign key (menu_item_id) references menu_item on delete cascade deferrable initially deferred,
    constraint menu_includes_menu_item_pk primary key (menu_id,menu_item_id));
    
create table customer(
    customer_id integer,
    title varchar(10),
    first_name varchar(15) not null,
    last_name varchar(15) not null,
    email_address varchar(30),
    contact_number varchar(15) not null,
    constraint customer_pk primary key (customer_id),
    constraint real_contact_numer check (regexp_like (contact_number,'^[0-9\+ \(\)]+$')),
--Contact_number only allows + () and numbers.
    constraint real_first_name check (REGEXP_LIKE (first_name,'^[A-Za-z]+$')),
    constraint real_last_name check (REGEXP_LIKE (last_name,'^[A-Za-z]+$')),
    constraint real_email_address check (REGEXP_LIKE (email_address,'^\w+@\w+(\.\w+)+$')));
--The regex is used to check the valid name and email_address.

--booking is a weak entity of customer, so its primary key should be the combination of customer_id and booking_id.
create table booking(
    customer_id integer not null,
    booking_id integer,
    end_date_and_time timestamp not null,
    start_date_and_time timestamp not null,
    number_of_people integer not null,
    special_requests varchar(500),
    constraint booking_fk foreign key (customer_id) references customer on delete cascade deferrable initially deferred,
    constraint booking_pk primary key (customer_id,booking_id),
    constraint real_time check(start_date_and_time<end_date_and_time),
    constraint real_people_number check(number_of_people>0));
    
create table the_table(
    table_id integer,
    location varchar(100) unique,
    --2 tables will not stay at the same position.
    seating_capacity integer not null,
    --This not null is used to check the number of people is no larger than the seating_capacity. 
    --If it is null, it means we don't know its capacity, and we can not make sure whether the number of people is larger than seating_capacity.
    comments varchar(500),
    constraint the_table_pk primary key (table_id));

--The relationship between booking and the_table is many-to-many, so we should create a new table.
--Each booking should have at least reserves one table, as far as I know, there are three ways to make it possible.
--First, use assertion, however, oracle doesn't approve it.
--Second, use check and in or exsits, however, becasue we have to use select in the subquery of in or exsits and oracle doesn't approve it, we can't use this solution.
--Third, use trigger, so we worte the at_least_reserves_one_table below.
create table reserves(
    customer_id integer not null,
    booking_id integer not null,
    table_id integer not null,
    constraint reserves_fk1 foreign key (customer_id,booking_id) references booking(customer_id,booking_id) on delete cascade deferrable initially deferred,
    constraint reserves_fk2 foreign key (table_id) references the_table(table_id) on delete cascade deferrable initially deferred,
    constraint reserves_pk primary key (customer_id,booking_id,table_id));
                   
create table orders(
    order_id integer,
    order_date_time timestamp not null,
    order_total_charge numeric(5,2) not null,
    table_id integer not null,
    constraint orders_fk foreign key (table_id) references the_table on delete cascade deferrable initially deferred,
    constraint orders_pk primary key (order_id));
 
--A order should have at least order_item, we have to use trigger, so we wrote the at_least_has_one_order_item trigger.
create table order_item(
    order_id integer not null,
    line_id integer not null,
    special_request varchar(500),
    charge numeric(5,2) not null,
    quantity integer,
    menu_item_id integer not null,
    constraint order_item_fk1 foreign key (order_id) references orders on delete cascade deferrable initially deferred,
    constraint order_item_fk2 foreign key (menu_item_id) references menu_item on delete cascade deferrable initially deferred,
    constraint order_item_pk primary key (order_id,line_id));

--We searched the Internet on how to use :new on https://docs.oracle.com/cd/B19306_01/server.102/b14200/statements_7004.htm.
--When we searched for some trigger examples, we found select .. into .. and raise_application_error and they helped a lot in my trigger writing. 
create trigger at_least_reserves_one_table
    after insert or update on booking
    for each row
    declare c1 number;
    begin
        select count(*) into c1 from reserves where reserves.booking_id=:new.booking_id and reserves.customer_id=:new.customer_id;
        if(c1=0) 
        then raise_application_error(-20001,'A booking must at least resrves one table.');
        end if;
    end;
/
--Because of this trigger, you should always insert values into 'reservers' before inserting values into 'booking'.

create trigger at_least_has_one_order_item
    after insert or update on orders
    for each row
    declare c2 number;
    begin
        select count(*) into c2 from order_item where order_item.order_id=:new.order_id;
        if(c2=0) 
        then raise_application_error(-20002,'A order must have at least one order item.');
        end if;
    end;
/
--Because of this trigger, you should always insert values into 'order_item' before inserting values into 'orders'.
    
            
create trigger table_capacity_restrict 
    after insert or update on booking
    for each row
    declare c3 number;
    begin 
        select count(*) into c3
                    from  reserves, the_table where :new.customer_id=reserves.customer_id and :new.booking_id=reserves.booking_id 
                     and reserves.table_id=the_table.table_id
                    and :new.number_of_people>the_table.seating_capacity ;
        if (c3 >0)
        then raise_application_error(-20003,'The number of people shouldn''t be greater than the seating capacity of the table.');
        end if;
    end;
/
--Because of this trigger, you should always insert values into 'reserves' and 'the_table' before inserting values into 'booking'.


insert into menu values ('hamburgers',1001,'Delicious hamburgers');
insert into menu values ('ice-creams',1002,'Declicious ice-creams');
insert into menu values ('drinkings',1003,'Delicisous drinkings');
insert into menu values ('Special',1004,'Cheap and decious');

insert into menu_item values ('A very delicious pork hamburger.','Pork Hamburger',101,10.5);
insert into menu_item values ('A very delicious beef hamburger.','Beef Hamburger',102,11);
insert into menu_item values ('A very delicious chicken hamburger.','Chicken Hamburger',103,6);
insert into menu_item values ('A very delicious mango ice-cream.','Mango ice-cream',201,5);
insert into menu_item values ('A very delicious oragne ice-cream.','Oragne ice-cream',202,5);
insert into menu_item values ('A very delicious apple ice-cream.','Apple ice-cream',203,4);
insert into menu_item values ('Delicious sparking.','Sparking',301,5);
insert into menu_item values ('Delicious orange juice.','Oragne juice',302,4);
insert into menu_item values ('Delicious apple juice.','Apple juice',303,2);
insert into menu_item values ('Delicious chips','Chips',401,5);

insert into menu_includes_menu_item values (1001,101);
insert into menu_includes_menu_item values (1001,102);
insert into menu_includes_menu_item values (1001,103);
insert into menu_includes_menu_item values (1002,201);
insert into menu_includes_menu_item values (1002,202);
insert into menu_includes_menu_item values (1002,203);
insert into menu_includes_menu_item values (1003,301);
insert into menu_includes_menu_item values (1003,302);
insert into menu_includes_menu_item values (1003,303);
insert into menu_includes_menu_item values (1004,401);
insert into menu_includes_menu_item values (1004,103);
insert into menu_includes_menu_item values (1004,203);
insert into menu_includes_menu_item values (1004,303);

insert into customer values (10001,'Mr.','Donald','Trump','twitterlover@usa.gov','+32 15648135');
insert into customer values (10002,'Dr.','Sheldon','Cooper','ineedadriver@gmail.com','(032)15648035');
insert into customer values (10003,'My lord', 'John','Snow','ilovemyaunt@gmail.com','+32 15648131');
insert into customer values (10004,'Mr.','Hongfeng','Guan','idontknowmybrother@gmail.com','+32 15648130');

insert into the_table values (1,'line 1, row 1',10,'The first table');
insert into the_table values (2,'line 2, row 2',8,'A good scene');
insert into the_table values (3,'line 5, row 6',1,'A special seat for ordianary Japanese high school student');

insert into reserves values(10001,1,1);
insert into reserves values(10001,1,2);
insert into reserves values(10001,2,1);
insert into reserves values(10002,1,2);
insert into reserves values(10003,1,3);
--If you delete the next line, the customer 10004 with booking_id 1 will not book a table, then the trigger at_least_reserves_one_table will be triggered when inserting values in booking.
insert into reserves values(10004,1,3);

insert into order_item values (11,1,'bigger than bigger',21,2,101);
insert into order_item values (11,2,'colder thant colder',20,5,201);
insert into order_item values (12,1,'bigger than bigger',21,2,102);
insert into order_item values (13,1,'bigger than bigger',21,2,101);
--If you delete the following line, the order 14 will have no order_item, then the at_least_has_one_order_item trigger will be triggered.
insert into order_item values (14,1,'bigger than bigger',21,2,401);

insert into orders values (11,to_timestamp('2017-05-06-23:55:12','yyyy-mm-dd hh24:mi:ss'),200,1);
insert into orders values (12,to_timestamp('2017-05-06-23:55:12','yyyy-mm-dd hh24:mi:ss'),200,1);
insert into orders values (13,to_timestamp('2017-05-06-23:55:12','yyyy-mm-dd hh24:mi:ss'),200,2);
insert into orders values (14,to_timestamp('2017-05-06-23:55:12','yyyy-mm-dd hh24:mi:ss'),200,3);

insert into booking values (10001,1,to_timestamp('2017-05-05 00:00:00','yyyy-mm-dd hh24:mi:ss'),to_timestamp('2017-04-04-23:55:00','yyyy-mm-dd hh24:mi:ss'),2,'We will make America great a again.');
insert into booking values (10001,2,to_timestamp('2017-06-05 00:00:00','yyyy-mm-dd hh24:mi:ss'),to_timestamp('2017-06-04-23:55:00','yyyy-mm-dd hh24:mi:ss'),2,'You are fired');
insert into booking values (10002,1,to_timestamp('2017-06-05 00:00:00','yyyy-mm-dd hh24:mi:ss'),to_timestamp('2017-06-04-23:55:00','yyyy-mm-dd hh24:mi:ss'),2,'Geology is not real science.');
insert into booking values (10003,1,to_timestamp('2017-06-05 00:00:00','yyyy-mm-dd hh24:mi:ss'),to_timestamp('2017-06-04-23:55:00','yyyy-mm-dd hh24:mi:ss'),1,'I know nothing');
insert into booking values (10004,1,to_timestamp('2017-06-05 00:00:00','yyyy-mm-dd hh24:mi:ss'),to_timestamp('2017-06-04-23:55:00','yyyy-mm-dd hh24:mi:ss'),1,'I did not mean to kill 500');
--If you insert the following line instead of the upper one, the number of people will be larger than the table capacity, and the trigger table_capacity_restrict will be triggered.
--insert into booking values (10004,1,to_timestamp('2017-06-05 00:00:00','yyyy-mm-dd hh24:mi:ss'),to_timestamp('2017-06-04-23:55:00','yyyy-mm-dd hh24:mi:ss'),100,'I did not mean to kill 500');


--If you update the number_of_people to 100 using the next line, the trigger table_capacity_restrict will be triggered.
--update booking set NUMBER_OF_PEOPLE=100 where CUSTOMER_ID=10001;

commit;

