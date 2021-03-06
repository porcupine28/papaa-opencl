#define FILTER_SIZE 5
__kernel void conv_2d(
    __global float *in,               // W*H input images
    __constant float *filt,           // K*K filter kernel
    __global float *out,              // W*H output images
    const int nFilterWidth,
    const int nFilterHeight,
    __global const float* pBias,
    __local float * image_buff)                // constant offset/bias
{

    int x = get_local_id(0);
    int y = get_local_id(1);

    int row = get_global_id(1);

    const int ImWidth  = get_global_size(0);
    const int ImHeight = get_global_size(1);
    const int OWidth   = ImWidth - nFilterWidth +1;
    const int OHeight  = ImHeight - nFilterHeight +1;

/*    __local float local_filt[ FILTER_SIZE* FILTER_SIZE];
    if(x < nFilterWidth*nFilterHeight)
    {
	local_filt[x] = filt[x];
    }
*/
    image_buff[y * ImWidth + x] = in[row * ImWidth + x];
    if(y > (get_local_size(1) - nFilterHeight))
    {
    	image_buff[(y+nFilterHeight-1)*ImWidth + x] = in[(row+nFilterHeight-1)*ImWidth + x];
    }
    barrier(CLK_LOCAL_MEM_FENCE);

    float sum = 0;
    for (int r = 0; r < nFilterHeight; r++) 
    {
        for(int c = 0; c < nFilterWidth; c++)
        {
            sum += filt[r*nFilterWidth + c]*image_buff[(y + r) * ImWidth + x + c];
        }
    }
    out[row * ImWidth + x] = sum + *pBias;
}


//#define LOCAL 1
__kernel void convolve(
	const __global float * pInput, 
	__constant float * pFilter, 
	__global float * pOutput, 
	const int nFilterWidth,
	const int nFilterHeight,
    __global const float * pBias,
	__local float* in_local) 
{

	const int x = get_global_id(0); 
	const int y = get_global_id(1);

    const int OWidth  = get_global_size(0);
    const int OHeight = get_global_size(1);

	const int ImWidth = OWidth+nFilterWidth-1;
	const int ImHeight  = OHeight + nFilterHeight -1;

#ifdef LOCAL
	event_t event;

	for(int i=0; i < get_local_size(1); i++)
 	{
		event = async_work_group_copy(&in_local[i*get_local_size(0)],&pInput[(get_group_id(1)*get_local_size(1)+i)*get_global_size(0)+(get_group_id(0)*get_local_size(0))],get_local_size(0),event);
	}
	wait_group_events(1, &event);
    // load data into the local RAM
    //in_local[y*ImWidth+x] = pInput[y*ImWidth+x];
    //in_local[y*ImWidth+x] = pInput[y*ImWidth+x];
	//barrier(CLK_LOCAL_MEM_FENCE);
#endif

	float sum = 0;
#pragma unroll 5
	for (int r = 0; r <nFilterHeight; r++) 
	{ 
#pragma unroll 5
		for(int c = 0; c <nFilterWidth; c++)
		{
#ifdef LOCAL
			sum += pFilter[r*nFilterWidth+c]*in_local[(y+r)*ImWidth+x+c];
#else
			sum += pFilter[r*nFilterWidth+c]*pInput[(y+r)*ImWidth+x+c];
#endif
		}
	}	
	pOutput[(y*OWidth)+x] = sum + *pBias;

}


__kernel void convolve_unroll(
        const __global float * pInput,
        __constant float * pFilter,
        __global float * pOutput,
        const int nFilterWidth,
        const int nFilterHeight,
        const int nInMaps,
        __global const float * pBias)
{
        const int x = get_global_id(0); 
        const int y = get_global_id(1);
        const int OWidth  = get_global_size(0);
        const int OHeight = get_global_size(1);
	const int ImWidth = OWidth+nFilterWidth-1;
	const int ImHeight = OHeight+nFilterHeight-1;	
        float sum = 0;
        int c = 0;
        for(int maps = 0; maps<nInMaps; maps++)
        {
             for (int r = 0; r <nFilterHeight; r++) 
             {
                int idxF = ((maps*nFilterHeight + r) * nFilterWidth) + c; 
                int idxIn = ((((maps*ImHeight) + y + r) * ImWidth) + x) + c;
                sum += pFilter[idxF]*pInput[idxIn]; 
                idxF++; 
                idxIn++; 
                sum += pFilter[idxF]*pInput[idxIn]; 
                idxF++; 
                idxIn++; 
                sum += pFilter[idxF]*pInput[idxIn]; 
                idxF++; 
                idxIn++; 
                sum += pFilter[idxF]*pInput[idxIn];
                idxF++;
                idxIn++;
                sum += pFilter[idxF]*pInput[idxIn];
                c += 5;
              }
        }
        pOutput[(y*OWidth)+x] = sum + *pBias;
}

__kernel void filter3D(
	const __global float * pInput, 
	__constant float * pFilter, 
	__global float * pOutput, 
	const int nFilterWidth,
	const int nFilterHeight,
	const int nInMaps,
        __global const float * pBias) 
{
	const int x = get_global_id(0); 
	const int y = get_global_id(1);
	const int z = get_global_id(2);

        const int ImWidth  = get_global_size(0);
        const int ImHeight = get_global_size(1);
	
	float sum = 0;
	int c = 0;
	int idxFstart = z*nFilterHeight*nFilterWidth*nInMaps;
/*
	if((get_global_id(0)==0) && (get_global_id(1)==0) && (get_global_id(2)==0))
	 printf("%d %d %d \n", get_num_groups(0),get_num_groups(1),get_num_groups(2));
	if((get_global_id(0)==0) && (get_global_id(1)==0) && (get_global_id(2)==18))
	{
	  for(int i=0;i<28*28;i++)
		printf("%f,",pInput[i]);
	  printf("---------->>>>>>>------\n\n\n");
	}
	if((get_global_id(0)==0) &&( get_global_id(1)==0) && (get_global_id(2)==0))
	{
	 for(int j =0; j < 20; j++)
	 {
	   for(int i=0; i<nInMaps*nFilterHeight*nFilterWidth; i++)
	   {
		printf("%f,",pFilter[j*nFilterHeight*nFilterWidth*nInMaps+i]);
	   }
	   printf("\n");
	 }
	 printf("\n \n \n");
	 for(int j=0;j<20;j++)
	  printf("%f",pBias[j]);
	printf("\n");
	}
	//printf("%d %d %d %p \n",x,y,z, &pOutput[((z*ImHeight*ImWidth)+(y*ImWidth)+x)]);
*/
	for(int maps = 0; maps<nInMaps; maps++)
	{ 
		for (int r = 0; r <nFilterHeight; r++) 
		{ 
			const int idxFtmp = idxFstart + (maps*nFilterHeight + r) * nFilterWidth; 
			const int idxIntmp = (((maps*ImHeight) + y + r) * ImWidth) + x;
			for(c = 0; c <nFilterWidth; c++)
			{
				const int idxF = idxFtmp + c;
				const int idxIn = idxIntmp + c;
				sum += pFilter[idxF]*pInput[idxIn];
			}
		}
	}
	pOutput[((z*ImHeight*ImWidth)+(y*ImWidth)+x)] = sum + pBias[z];
}


__kernel void filter3D_unroll(
        const __global float * pInput,
        __constant float * pFilter,
        __global float * pOutput,
        const int nFilterWidth,
        const int nFilterHeight,
        const int nInMaps,
        __global const float * pBias)
{
        const int x = get_global_id(0); 
        const int y = get_global_id(1);
	const int z = get_global_id(2);

        const int ImWidth  = get_global_size(0);
        const int ImHeight = get_global_size(1);

        float sum = 0;
        int c = 0;

	int idxFtmp = z*nFilterHeight*nFilterWidth*nInMaps;

        for(int maps = 0; maps<nInMaps; maps++)
        {
             for (int r = 0; r <nFilterHeight; r++) 
             {
                int idxF = idxFtmp + ((maps*nFilterHeight + r) * nFilterWidth) + c; 
                int idxIn = ((((maps*ImHeight) + y + r) * ImWidth) + x) + c;
                sum += pFilter[idxF]*pInput[idxIn]; 
                idxF++; 
                idxIn++; 
                sum += pFilter[idxF]*pInput[idxIn]; 
                idxF++; 
                idxIn++; 
                sum += pFilter[idxF]*pInput[idxIn]; 
                idxF++; 
                idxIn++; 
                sum += pFilter[idxF]*pInput[idxIn];
                idxF++;
                idxIn++;
                sum += pFilter[idxF]*pInput[idxIn];
                c += 5;
              }
        }
        pOutput[(y*ImWidth)+x] = sum + *pBias;
}
__kernel void filter3D_2(
	const __global float * pInput, 
	__constant float * pFilter, 
	__global float * pOutput, 
	const int nFilterWidth,
	const int nFilterHeight,
	const int nInMaps,
        __global const float * pBias) 
{
	const int x = get_global_id(0); 
	const int y = get_global_id(1);
	const int z = get_global_id(2);

        const int OWidth  = get_global_size(0);
        const int OHeight = get_global_size(1);
	const int ImWidth = OWidth+nFilterWidth-1;
	const int ImHeight = OHeight+nFilterHeight-1;	
	float sum = 0;
	int c = 0;
	int idxFstart = z*nFilterHeight*nFilterWidth*nInMaps;

	   for(int maps = 0; maps<nInMaps; maps++)
	   { 
		for (int r = 0; r <nFilterHeight; r++) 
		{ 
			const int idxFtmp = idxFstart + (maps*nFilterHeight + r) * nFilterWidth; 
			const int idxIntmp = (((maps*ImHeight) + y + r) * ImWidth) + x;
			for(c = 0; c <nFilterWidth; c++)
			{
				const int idxF = idxFtmp + c;
				const int idxIn = idxIntmp + c;
				sum += pFilter[idxF]*pInput[idxIn];
			}
		}
	   }  
	   pOutput[((z*OHeight*OWidth)+(y*OWidth)+x)] = sum + pBias[z];
}

__kernel void filter3D_1(
	const __global float * pInput, 
	__constant float * pFilter, 
	__global float * pOutput, 
	const int nFilterWidth,
	const int nFilterHeight,
	const int nInMaps,
        __global const float * pBias) 
{
	const int x = get_global_id(0); 
	const int y = get_global_id(1);
	const int z = get_global_id(2);

        const int ImWidth  = get_global_size(0);
        const int ImHeight = get_global_size(1);
	const int OWidth   = ImWidth - nFilterWidth +1;
	const int OHeight  = ImHeight - nFilterHeight +1;
	
	float sum = 0;
	int c = 0;
	int idxFstart = z*nFilterHeight*nFilterWidth*nInMaps;

	if((get_global_id(0)< OWidth) && (get_global_id(1)< OHeight))
	{
	   for(int maps = 0; maps<nInMaps; maps++)
	   { 
		for (int r = 0; r <nFilterHeight; r++) 
		{ 
			const int idxFtmp = idxFstart + (maps*nFilterHeight + r) * nFilterWidth; 
			const int idxIntmp = (((maps*ImHeight) + y + r) * ImWidth) + x;
			for(c = 0; c <nFilterWidth; c++)
			{
				const int idxF = idxFtmp + c;
				const int idxIn = idxIntmp + c;
				sum += pFilter[idxF]*pInput[idxIn];
			}
		}
	   }  
	   pOutput[((z*OHeight*OWidth)+(y*OWidth)+x)] = sum + pBias[z];
	}
}

