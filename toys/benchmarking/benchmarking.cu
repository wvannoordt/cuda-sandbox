#include <stdio.h>
#include <time.h>

#define DEBUG false


// Simple SAXPY operation.
__global__ void cuda_saxpy_mat_1(int N, float a, float *x, float *y)
{
	int index = blockIdx.x*blockDim.x + threadIdx.x;
	if (index < N*N)
	{
		y[index] = a * x[index] + y[index];
	}
}

void wait()
{
	puts("Press any key to continue...");
	getchar();
}

// Heavy lifting
double run_computation(bool on_gpu, int N)
{
#if(DEBUG)
	printf("N = %d\n\n", N);
#endif

	float a = 6.0f;
	float *host_x, *host_y, *device_x, *device_y;
	
	host_x = (float*)malloc(N*N*sizeof(float));
	host_y = (float*)malloc(N*N*sizeof(float));

	if (on_gpu)
	{
		cudaMalloc(&device_x, N*N*sizeof(float)); 
		cudaMalloc(&device_y, N*N*sizeof(float));
	}
	dim3 blocks_per_grid((N*N+255)/256, 1, 1);
	dim3 threads_per_block(256, 1, 1);
	for (int j = 0; j < N; j++)
	{
		for (int i = 0; i < N; i++) 
		{
			*(host_x + i*N + j) = 1.0f;
			*(host_y + i*N + j) = 3.0f;
		}
	}

#if (DEBUG)
	printf("Initializing...\n");
	printf("x[0][0]     = %f\n", *(host_x + 0*N + 0));
	printf("...\n");
	printf("x[N-1][N-1] = %f\n\n", *(host_x + (N-1)*N + (N-1)));

	printf("y[0][0]     = %f\n", *(host_y + 0*N + 0));
	printf("...\n");
	printf("y[N-1][N-1] = %f\n\n", *(host_y + (N-1)*N + (N-1)));
#endif

	if (on_gpu)
	{
		cudaMemcpy(device_x, host_x, N*N*sizeof(float), cudaMemcpyHostToDevice);
		cudaMemcpy(device_y, host_y, N*N*sizeof(float), cudaMemcpyHostToDevice);
	}
	
#if (DEBUG)
	printf("Computing y[i][j] = 6*x[i][j] + y[i][j]\n\n");
#endif

	clock_t start, end;
	double time_used;
	if (on_gpu)
	{
		// Runs on the GPU.
		start = clock();
		cuda_saxpy_mat_1<<<blocks_per_grid,threads_per_block>>>(N, a, device_x, device_y);
		
		// This is only a fair comparison if the device synchronization is invoked, since it awaits the end of the computation.
		cudaDeviceSynchronize();
		end = clock();
	}
	else
	{
		// Runs on the CPU.
		start = clock();
		for (int j = 0; j < N; j++)
		{
			for (int i = 0; i < N; i++) 
			{
				*(host_y + i*N + j) = a * *(host_x + i*N + j) + *(host_y + i*N + j);
			}
		}
		end = clock();
	}
	
	time_used = ((double) (end - start)) / CLOCKS_PER_SEC;
	if (on_gpu)
	{
		cudaMemcpy(host_y, device_y, N*N*sizeof(float), cudaMemcpyDeviceToHost);
		cudaDeviceSynchronize();
	}
	
#if (DEBUG)
	printf("Outputting...\n");
	printf("x[0][0]     = %f\n", *(host_x + 0*N + 0));
	printf("...\n");
	printf("x[N-1][N-1] = %f\n\n", *(host_x + (N-1)*N + 0*(N-1)));

	printf("y[0][0]     = %f\n", *(host_y + 0*N + 0));
	printf("...\n");
	printf("y[N-1][N-1] = %f\n\n", *(host_y + (N-1)*N + (N-1)));
	
	printf("Elapsed time: %f ms\n\n", 1e3*time_used);
#endif
	if (on_gpu)
	{
		cudaFree(device_x);
		cudaFree(device_y);
	}
#if (DEBUG)
	if (on_gpu)
	{
		printf("Look how fast that was!\n\n\n");
	}
	else
	{
		printf("Look how fast that wasn't!\n\n\n");
	}
#endif
	if (*(host_y + (N-1)*N + (N-1)) < 5.0f)
	{
		printf("Error detected. Stop.\n\n");
		exit(1);
	}
	free(host_x);
	free(host_y);
	return 1e3*time_used;
}

int main() 
{
	// Benchmarks a SAXPY matrix operation on CPU vs GPU
	
	// Define the dimensions of the matrix. GPU performance overtakes CPU performance around N = 2^11 - 2^12 (64 MB).
	// Program crashes for N = 2^15 (4 GB).
	int N = 1<<14;
	int N2 = N*N;
	
	// Output
	printf("Runtimes for N*N = %d (%f MB):\n\n", N2, sizeof(float)*N2/(1024.0f*1024.0f));
	
	clock_t start, end;
	double time_used_total_cpu, time_used_total_gpu;
	
	
	// Run on GPU first
	start = clock();
	double gpu_time = run_computation(true, N);
	end = clock();
	time_used_total_gpu = 1e3*((double) (end - start)) / CLOCKS_PER_SEC;
	
	// Run on CPU
	start = clock();
	double cpu_time = run_computation(false, N);
	end = clock();
	time_used_total_cpu = 1e3*((double) (end - start)) / CLOCKS_PER_SEC;
	
	// Output
	printf("    CPU computation: %f ms\n", cpu_time);
	printf("    CPU total:       %f ms\n\n", time_used_total_cpu);
	printf("    GPU computation: %f ms\n", gpu_time);
	printf("    GPU total:       %f ms\n\n", time_used_total_gpu);
	return 0;
}
