# ----------------------------------
# User defined function
# ----------------------------------
pause(){
  read -p "Press [Enter] key to continue..." fackEnterKey
}

Node_down(){
        
        echo -e "${V_RED}${V_UNDERLINE}Below are the down node${V_RESET}\n"
        /opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select node_name,node_address,export_address,node_state from nodes where node_state ilike 'DOWN'" 
        
        IP_LIST=$(/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select node_address from nodes where node_state ilike 'DOWN'"|sed '1,2d' | sed -n -e :a -e '1,2!{P;N;D;};N;ba')

        for SERVER_IP in $IP_LIST
        do
           if nc -z $SERVER_IP 22 2>/dev/null; then
               echo "$SERVER_IP ✓"
           else
               echo "$SERVER_IP ✗"
           fi
        done

        
        pause
}

# Catalog_Size Calculates In-Memory catalog size per node
Catalog_Size(){

echo -e "${V_RED}${V_UNDERLINE}In Memory Catalog Size of database per node-Look for odd Size and Catalog size more than 10 GB${V_RESET}"

/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "SELECT node_name, MAX (ts) AS ts, MAX(catalog_size_in_GB) AS catlog_size_in_GB FROM 
 (SELECT node_name,TRUNC((dc_allocation_pool_statistics_by_second."time")::TIMESTAMP,'SS'::VARCHAR(2)) AS ts,ROUND(SUM((dc_allocation_pool_statistics_by_second.total_memory_max_value - dc_allocation_pool_statistics_by_second.free_memory_min_value))/(1024*1024*1024),3.0) AS catalog_size_in_GB from dc_allocation_pool_statistics_by_second GROUP BY 1,TRUNC((dc_allocation_pool_statistics_by_second."time")::TIMESTAMP,'SS'::VARCHAR(2))) subquery_1 GROUP BY 1 ORDER BY 1 LIMIT 50"
        
pause
}


#Calculate Partitions which is contributing most to Catalog Size
Partition_size(){
         echo -e "${V_RED}${V_UNDERLINE}Partitions contributing to large Catalog Size${V_RESET}\n"
        /opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "SELECT s.node_name,p.table_schema,s.projection_name,COUNT(DISTINCT s.storage_oid) storage_container_count,COUNT(DISTINCT partition_key) partition_count,COUNT(r.rosid) ros_file_count FROM storage_containers s LEFT OUTER JOIN PARTITIONS p ON s.storage_oid = p.ros_id JOIN vs_ros r ON r.delid = s.storage_oid GROUP BY 1,2,3 ORDER BY 4 DESC LIMIT 50;"
        pause
}


Performance_Vertica(){

echo -e "${V_RED}${V_UNDERLINE}Look for nodes which have high thread count and open file handle count relative to other nodes${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select node_name,sum(thread_count) as thread_count,sum(open_file_handle_count) as open_file_handle_count,sum(memory_inuse_kb)/1000000 as memory_inuse_GB from resource_acquisitions where is_executing ='t' group by node_name order by node_name"

echo -e "${V_RED}${V_UNDERLINE}CPU and Memory Usage per node for last 6 hours${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "SELECT node_name, ROUND(AVG(average_cpu_usage_percent),3.0) AS avg_cpu_usage,ROUND(AVG(average_memory_usage_percent),3.0) AS avg_mem_usage FROM v_monitor.system_resource_usage WHERE  end_time BETWEEN sysdate() - INTERVAL '6 hours' AND sysdate() GROUP  BY node_name order by node_name LIMIT  30"


echo -e "${V_RED}${V_UNDERLINE}NETWORK USAGE Per Node for last 6 hours${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "SELECT node_name, ROUND(AVG(net_rx_kbytes_per_second),3.0) AS avg_rx_kb_per_second, ROUND(AVG(net_tx_kbytes_per_second),3.0) AS avg_tx_kb_per_second FROM v_monitor.system_resource_usage WHERE end_time BETWEEN sysdate() - INTERVAL '6 hours' AND sysdate() GROUP  BY node_name order by node_name LIMIT  30"


echo -e "${V_RED}${V_UNDERLINE}Disk IO usage Per Node for last 6 hours${V_RESET}"

/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "SELECT node_name, ROUND(AVG(io_read_kbytes_per_second),3.0) AS avg_io_read_kb_per_second,ROUND(AVG(io_written_kbytes_per_second),3.0) AS avg_io_written_kbytes_per_second FROM v_monitor.system_resource_usage WHERE  end_time BETWEEN sysdate() - INTERVAL '6 hours' AND sysdate() GROUP  BY node_name order by node_name LIMIT 30"

pause

}
AHM_lag(){
echo -e "${V_RED}${V_UNDERLINE}AHM lag${V_RESET}\n" 
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select current_epoch,ahm_epoch,last_good_epoch,last_good_epoch - ahm_epoch ahm_lag from system;"

echo -e "${V_RED}${V_UNDERLINE}Refresh below unrefreshed projections if any ${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select projection_schema,projection_name,owner_name,anchor_table_name,is_up_to_date,has_statistics from projections where not is_up_to_date;"

echo -e "${V_RED}${V_UNDERLINE}Reason for unrefreshed Projections${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select P.projection_schema,P.projection_name,P.anchor_table_name,P.is_up_to_date,PR.refresh_status,PR.refresh_method,PR.refresh_start from projections P left outer join PROJECTION_REFRESHES PR on P.projection_id=PR.projection_id where P.is_up_to_date='f' order by PR.refresh_start desc;"

pause
}


Disk_utilization(){

echo -e "${V_RED}${V_UNDERLINE}Catalog Size per node if Catalog disk usage is more than 80 Percentage${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select node_name,storage_path,round((disk_space_free_mb/1024),3.0) as disk_space_free_gb,round((disk_space_used_mb/1024),3.0) as disk_space_used_gb,(100 - (TRIM(TRAILING '%' from disk_space_free_percent)::integer)) as disk_space_used_percent from disk_storage where storage_usage ilike '%CATALOG%'"


echo -e "${V_RED}${V_UNDERLINE}Data Size per node if Data disk usage is more than 80 Percentage${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select node_name,storage_path,round((disk_space_free_mb/1024),3.0) as disk_space_free_gb,round((disk_space_used_mb/1024),3.0) as disk_space_used_gb,(100 - (TRIM(TRAILING '%' from disk_space_free_percent)::integer)) as disk_space_used_percent from disk_storage where storage_usage ilike '%DATA%'"

echo -e "${V_RED}${V_UNDERLINE}Ask Application team to archive old data of below table${V_RESET}\n"

/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select PROJECTION_SCHEMA,anchor_table_name,round((sum(used_bytes)/(1024*1024*1024)),3.0) table_size_in_gb from projection_storage group by PROJECTION_SCHEMA,anchor_table_name order by table_size_in_Gb desc limit 10"

pause
}


Vertica_System_Information(){

echo -e "${V_RED}${V_UNDERLINE}General Vertica Database Info like DB name,size,number of nodes etc${V_RESET}\n"

/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select name as database_name,DATE_TRUNC('second',starttime::TIMESTAMP) as last_start_time_of_DB,compliance_level,compliance_message,license_size from vs_databases"

/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select current_epoch,ahm_epoch,last_good_epoch,designed_fault_tolerance,node_count,node_down_count,wos_used_bytes,wos_row_count,ros_used_bytes,ros_row_count,total_row_count,round(total_used_bytes/(1024*1024*1024*1024),2.0) as Database_size_Terabytes from system"

pause
}


Running_queries(){

echo -e "${V_RED}${V_UNDERLINE}Session/transactions of executing queries${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select session_id,transaction_id,statement_id,node_name,query_start_epoch,DATE_TRUNC('second',query_start::TIMESTAMP) as query_start,left(query,80) from query_profiles where is_executing='t' and user_name!='dbadmin' order by query_start desc"

pause
}



Top_queries_by_execution_wait_time(){

echo -e "${V_RED}${V_UNDERLINE}Ten successful Queries which consumed most time in Database${V_RESET}\n"

/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select node_name,user_name,session_id,transaction_id,statement_id,request_type,round((memory_acquired_mb/1024),3.0) as memory_acq_Gb,DATE_TRUNC('second',start_timestamp::TIMESTAMP) as start_timestamp,DATE_TRUNC('second',end_timestamp::TIMESTAMP) as end_timestamp,round(request_duration_ms/1000,3.0) as req_dur_sec,left(request,70) as Query from query_requests where success='t' order by req_dur_sec desc limit 10"



echo -e "${V_RED}${V_UNDERLINE}Ten failed Queries which consumed most time in Database${V_RESET}\n"

/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select node_name,user_name,session_id,transaction_id,statement_id,request_type,round((memory_acquired_mb/1024),3.0) as memory_acq_Gb,DATE_TRUNC('second',start_timestamp::TIMESTAMP) as start_timestamp,DATE_TRUNC('second',end_timestamp::TIMESTAMP) as end_timestamp,round(request_duration_ms/1000,3.0) as req_dur_sec,left(request,70) as Query from query_requests where success='f' order by req_dur_sec desc limit 10"


echo -e "${V_RED}${V_UNDERLINE}Top 10 queries by their wait time in queue${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "SELECT RA.node_name,RA.transaction_id,RA.statement_id,RA.pool_name,
DATE_TRUNC('second',RA.queue_entry_timestamp::TIMESTAMP) as queue_entry_time,
DATE_TRUNC('second',RA.acquisition_timestamp::TIMESTAMP) as acquisition_time,
(RA.acquisition_timestamp-RA.queue_entry_timestamp) AS queue_wait,
left(QR.request,70) as Query
FROM V_MONITOR.RESOURCE_ACQUISITIONS as RA inner join query_requests as QR 
on RA.transaction_id=QR.transaction_id and RA.statement_id=QR.statement_id 
order by queue_wait desc limit 10"


pause
}


Top_queries_by_execution_wait_time_in_last_6_hr(){

echo -e "${V_RED}${V_UNDERLINE}Ten successful Queries which consumed most time in Database in last 6 hour${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select node_name,user_name,session_id,transaction_id,statement_id,request_type,round((memory_acquired_mb/1024),3.0) as memory_acq_Gb,DATE_TRUNC('second',start_timestamp::TIMESTAMP) as start_timestamp,DATE_TRUNC('second',end_timestamp::TIMESTAMP) as end_timestamp,round(request_duration_ms/1000,3.0) as req_dur_sec,left(request,70) as Query from query_requests
where success='t' and start_timestamp BETWEEN sysdate() - INTERVAL '6 hours' AND sysdate()
order by req_dur_sec desc limit 10"

echo -e "${V_RED}${V_UNDERLINE}Ten failed Queries which consumed most time in Database in last 6 hour${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select node_name,user_name,session_id,transaction_id,statement_id,request_type,round((memory_acquired_mb/1024),3.0) as memory_acq_Gb,DATE_TRUNC('second',start_timestamp::TIMESTAMP) as start_timestamp,DATE_TRUNC('second',end_timestamp::TIMESTAMP) as end_timestamp,round(request_duration_ms/1000,3.0) as req_dur_sec,left(request,70) as Query from query_requests
where success='f' and start_timestamp BETWEEN sysdate() - INTERVAL '6 hours' AND sysdate()
order by req_dur_sec desc limit 10"

echo -e "${V_RED}${V_UNDERLINE}Top 10 queries by their wait time in queue in last 6 hour${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "SELECT RA.node_name,RA.transaction_id,RA.statement_id,RA.pool_name,
DATE_TRUNC('second',RA.queue_entry_timestamp::TIMESTAMP) as queue_entry_time,
DATE_TRUNC('second',RA.acquisition_timestamp::TIMESTAMP) as acquisition_time,
(RA.acquisition_timestamp-RA.queue_entry_timestamp) AS queue_wait,
left(QR.request,70) as Query
FROM V_MONITOR.RESOURCE_ACQUISITIONS as RA inner join query_requests as QR 
on RA.transaction_id=QR.transaction_id and RA.statement_id=QR.statement_id 
where RA.acquisition_timestamp BETWEEN sysdate() - INTERVAL '6 hours' AND sysdate()
order by queue_wait desc limit 10"

pause
}


Resource_Pools_usage()
{

echo -e "${V_RED}${V_UNDERLINE}System Defined resource pool usage${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "SELECT name,memorysize,maxmemorysize,executionparallelism,plannedconcurrency,maxconcurrency,runtimecap,queuetimeout,priority,runtimepriority,runtimeprioritythreshold,cpuaffinityset,cpuaffinitymode,cascadeto,singleinitiator FROM V_CATALOG.RESOURCE_POOLS where is_internal='t'"

echo -e "${V_RED}${V_UNDERLINE}User Defined resource pool usage${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "SELECT name,memorysize,maxmemorysize,executionparallelism,plannedconcurrency,maxconcurrency,runtimecap,queuetimeout,priority,runtimepriority,runtimeprioritythreshold,cpuaffinityset,cpuaffinitymode,cascadeto,singleinitiator FROM V_CATALOG.RESOURCE_POOLS where is_internal='f'"

echo -e "${V_RED}${V_UNDERLINE}Top 10 Resource acquisitions in each System defined resource pool${V_RESET}\n"

/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select pool_name,node_name,transaction_id,statement_id,priority,memory_kb,filehandles,threads,queries,DATE_TRUNC('second',start_time::TIMESTAMP) as start_time,succeeded,result,failing_resource,is_required from dc_resource_acquisitions where pool_name in (select name FROM V_CATALOG.RESOURCE_POOLS where is_internal='t') limit 10 over( partition by pool_name order by memory_kb desc,filehandles desc,threads desc)"


echo -e "${V_RED}${V_UNDERLINE}Top 10 Resource acquisitions in each User defined resource pool${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select pool_name,node_name,transaction_id,statement_id,priority,memory_kb,filehandles,threads,queries,DATE_TRUNC('second',start_time::TIMESTAMP) as start_time,succeeded,result,failing_resource,is_required from dc_resource_acquisitions where pool_name in (select name FROM V_CATALOG.RESOURCE_POOLS where is_internal='f') limit 10 over( partition by pool_name order by memory_kb desc,filehandles desc,threads desc)"


echo -e "${V_RED}${V_UNDERLINE}Top 10 Resource rejection for each pool${V_RESET}\n"

/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select pool_name,DATE_TRUNC('second',rejected_timestamp::TIMESTAMP) as rejected_timestamp,node_name,user_name,session_id,transaction_id,statement_id,reason ,resource_type,rejected_value from resource_rejection_details limit 10 over( partition by pool_name order by rejected_timestamp desc)"


echo -e "${V_RED}${V_UNDERLINE}Top 10 Resource rejection for each resource type${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select resource_type,pool_name,DATE_TRUNC('second',rejected_timestamp::TIMESTAMP) as rejected_timestamp,node_name,user_name,session_id,transaction_id,statement_id,reason,rejected_value FROM resource_rejection_details LIMIT 10 OVER (PARTITION BY resource_type ORDER BY rejected_timestamp DESC)"

pause
}


Locks_checking()
{

echo -e "${V_RED}${V_UNDERLINE}Transaction failed to get lock in last 3 days${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select DATE_TRUNC('second',time::TIMESTAMP) as time ,node_name,session_id,user_name,transaction_id,object_name,mode,promoted_mode,scope,DATE_TRUNC('second',start_time::TIMESTAMP),timeout_in_seconds,result,description from dc_lock_attempts where time  BETWEEN sysdate() - interval '3 days' and sysdate() and result not ilike '%granted%' order by time asc"

echo -e "${V_RED}${V_UNDERLINE}Locks on Catalog${V_RESET}\n"  
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select DATE_TRUNC('second',l.time::TIMESTAMP) as time,ri.transaction_id,ri.statement_id,l.node_name,l.time-l.grant_Time as duration, l.object_name,l.mode,substring(ri.request,0,70) from dc_lock_releases l join dc_requests_issued ri on l.transaction_id=ri.transaction_id where l.object_name ilike '%Catalog%' order by duration desc limit 10"

echo -e "${V_RED}${V_UNDERLINE}Current locks in Database${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "select object_name,lock_mode,lock_scope,DATE_TRUNC('second',request_timestamp::TIMESTAMP) as request_time,DATE_TRUNC('second',grant_timestamp::TIMESTAMP) as grant_time,(grant_timestamp - request_timestamp) as wait_time_for_lock,transaction_id,substring(transaction_description,20,70) as transaction_description from locks order by request_timestamp desc"

pause
}


Delete_vector_rows(){


echo -e "${V_RED}${V_UNDERLINE}Top 10 projections having highest Delete Vectors${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "SELECT schema_name
          ,projection_name
          ,count(*) num_ros
          ,sum(total_row_count) num_rows
          ,sum(deleted_row_count) num_deld_rows
          ,sum(delete_vector_count) Num_dv
          ,(sum(deleted_row_count) / sum(total_row_count) * 100)::INT per_del_rows
FROM storage_containers
WHERE node_name = ( SELECT local_node_name())
GROUP BY 1, 2
ORDER BY 6 DESC
limit 10"


echo -e "${V_RED}${V_UNDERLINE}Top 10 projections having highest Rows${V_RESET}\n"
/opt/vertica/bin/vsql -U dbadmin -w $PASSWORD -c "SELECT schema_name
          ,projection_name
          ,count(*) num_ros
          ,sum(total_row_count) num_rows
          ,sum(deleted_row_count) num_deld_rows
          ,sum(delete_vector_count) Num_dv
          ,(sum(deleted_row_count) / sum(total_row_count) * 100)::INT per_del_rows
FROM storage_containers
WHERE node_name = ( SELECT local_node_name())
GROUP BY 1, 2
ORDER BY 5 DESC 
limit 10"

pause
}

scrutinize(){

read -p "Please enter case number for which you are running scrutinize : " message

/opt/vertica/bin/scrutinize -U dbadmin -P $PASSWORD -m $message 

pause
}
