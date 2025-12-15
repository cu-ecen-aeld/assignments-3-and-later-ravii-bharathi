#include "threading.h"
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

// Optional: use these functions to add debug or error prints to your application
#define DEBUG_LOG(msg,...)
//#define DEBUG_LOG(msg,...) printf("threading: " msg "\n" , ##__VA_ARGS__)
#define ERROR_LOG(msg,...) printf("threading ERROR: " msg "\n" , ##__VA_ARGS__)

void* threadfunc(void* thread_param)
{

    // TODO: wait, obtain mutex, wait, release mutex as described by thread_data structure
    // hint: use a cast like the one below to obtain thread arguments from your parameter
    //struct thread_data* thread_func_args = (struct thread_data *) thread_param;
	
	//casting param to thread_data
	struct thread_data* thread_func_args = (struct thread_data *) thread_param;

	//convert milliseconds to microseconds (1millisecond = 1000 microseconds)
	//wait to obtain mutex
	usleep(thread_func_args->wait_to_obtain_ms * 1000);
	DEBUG_LOG("thread waiting complete, attempting to obtain mutex");

	//obtaining mutex
	if(pthread_mutex_lock(thread_func_args->mutex) != 0){
		ERROR_LOG("failed to obtain Mutex");
		thread_func_args->thread_complete_success = false;
		return thread_param;
	}
	DEBUG_LOG("Mutex obtained successfully");

	//hold mutex
	usleep(thread_func_args->wait_to_release_ms * 1000);
	DEBUG_LOG("release wait complete");

	//release mutex
	if(pthread_mutex_unlock(thread_func_args->mutex) != 0){
		ERROR_LOG("failed to release Mutex");
		thread_func_args->thread_complete_success = false;
		return thread_param;
	}
	DEBUG_LOG("mutex released successfully");

	//mark success in thread_complete_success in thread_data structure
	thread_func_args->thread_complete_success = true;
	return thread_param;
}


bool start_thread_obtaining_mutex(pthread_t *thread, pthread_mutex_t *mutex,int wait_to_obtain_ms, int wait_to_release_ms)
{
    /**
     * TODO: allocate memory for thread_data, setup mutex and wait arguments, pass thread_data to created thread
     * using threadfunc() as entry point.
     *
     * return true if successful.
     *
     * See implementation details in threading.h file comment block
     */
	struct thread_data *thread_args = (struct thread_data *)malloc(sizeof(struct thread_data));

	if(thread_args = NULL){
		ERROR_LOG("memory allocation failed for thread_data");
		return false;
	}

	//initialize fields in thread_data
	thread_args->wait_to_obtain_ms = wait_to_obtain_ms;
	thread_args->wait_to_release_ms = wait_to_release_ms;
	thread_args->mutex = mutex;
	thread_args->thread_complete_success = false;

	//create the thread with threadfunc as entry
	if(pthread_create(thread, NULL, threadfunc, thread_args) != 0){
		ERROR_LOG("Failed to create thread!");
		free(thread_args);
		return false;
	}

	//store the thread ID in thre structure for reference
	thread_args->thread_id = *thread;
	DEBUG_LOG("Thread created successfully with ID");
	
	//return true indicating successful thread creation
	return true;
}

