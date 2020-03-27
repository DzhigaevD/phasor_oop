classdef PostPhasor < handle
    %   PHASOR Summary of this class goes here
    %   3D version
    % h - horizontal axis of the diffraction pattern
    % v - vertical axis of the diffraction pattern
    % r - rocking curve direction (3 dimension in arrays)
    % List of methods:
   
    properties
        data;
        dataTime;        
        path;
        experiment;                        
        object_fft_mod;    
        object_sampling;        
        object;
        displacement;
        strain;
        plotting;
        mask;
        strain_mask;
        prtf;
        
        % Constants. They are needed for correct labeling of axes
        h                       = 4.1357e-15;                                  % Plank's constant
        c                       = 2.99792458e8;                                % Speed of light in vacuum
    end
        
    % - Constructor of the object -    
    methods
        function postPhasor = PostPhasor(input_param)
            
            postPhasor.path = input_param.path;
            
            try
                postPhasor.object = input_param.object;
                postPhasor.mask = ones(size(postPhasor.object));
            catch 
                error('No reconstruction found!');
            end
            
            try
                postPhasor.experiment = input_param.experiment;
                 postPhasor.experiment.wavelength = postPhasor.h*postPhasor.c/postPhasor.experiment.energy;
            catch
                warning('No experimental parameters found! Coordinate transform is not possible!')
            end
            
            try
                postPhasor.object_sampling = input_param.object_sampling;
                postPhasor.update_plotting_vectors;
            catch
                error('No real-space sampling defined!');
            end
            
                        
            disp('PostPhasor instance created succesfully');
        end
    end  
    
    methods
        % Load methods %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function load_data_mat(postPhasor)
            % Dynamic determination of the dataset name
            in = load(postPhasor.experiment.data_path); 
            names = fieldnames(in);
            temp = in.(names{1});
            clear in;           
            
%             temp(isnan(temp)) = 0;
%             if temp<0
%                 postPhasor.data_gap = (temp==-1);
%                 temp(postPhasor.data_gap) = 0;
%                 disp('Gaps are recorded!');
%             else
%                 postPhasor.data_gap = (temp==-1);
%                 disp('No gaps');
%             end            
            
            postPhasor.data = single((double(temp)));
                        
            fprintf('Data loaded: %s\n',postPhasor.experiment.data_path);
            fprintf('Data size: [%d %d %d]\n',size(postPhasor.data));
        end    
        
        function load_object_mat(postPhasor)
            % Dynamic determination of the dataset name
            in = load(postPhasor.data_meta.reconstruction_path); 
            names = fieldnames(in);
            temp = in.(names{1});
            clear in;                                               
            
            postPhasor.object = temp;            
            
            fprintf('Sample reconstruction loaded: %s\n',postPhasor.data_meta.reconstruction_path);            
        end     
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
        % Class methods %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                                                                                         
        function update_plotting_vectors(postPhasor)
            postPhasor.plotting.object.vector1 = (-size(postPhasor.object,1)/2:size(postPhasor.object,1)/2-1).*postPhasor.object_sampling*1e9; % [nm convention]
            postPhasor.plotting.object.vector2 = (-size(postPhasor.object,2)/2:size(postPhasor.object,2)/2-1).*postPhasor.object_sampling*1e9;
            postPhasor.plotting.object.vector3 = (-size(postPhasor.object,3)/2:size(postPhasor.object,3)/2-1).*postPhasor.object_sampling*1e9;
            
            if postPhasor.strain
                postPhasor.plotting.strain.vector1 = (-size(postPhasor.strain,1)/2:size(postPhasor.strain,1)/2-1).*postPhasor.object_sampling*1e9; % [nm convention]
                postPhasor.plotting.strain.vector2 = (-size(postPhasor.strain,2)/2:size(postPhasor.strain,2)/2-1).*postPhasor.object_sampling*1e9;
                postPhasor.plotting.strain.vector3 = (-size(postPhasor.strain,3)/2:size(postPhasor.strain,3)/2-1).*postPhasor.object_sampling*1e9;
                disp('Plotting vectors for strain updated!');
            end
            
            disp('Plotting vectors for object updated!');
        end
        
        function create_mask(postPhasor,value)    
            if nargin == 1
                value = 0.1;
            end
            postPhasor.mask = abs(postPhasor.object) > value*max(abs(postPhasor.object(:)));
            fprintf('Mask is updated to %.2f of max amplitude\n',value);
        end
        
        function calculate_object_fft_mod(postPhasor)
            % Should we compare the same volume inside the support
                % only, since everything outside is not an object?
            postPhasor.object_fft_mod = abs(fftNc(postPhasor.object));            
        end                                                            
        
        % Post-processing %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function flip(postPhasor,dimension)
            postPhasor.object = flip(postPhasor.object,dimension);
            fprintf('Object is flipped along dimension %d\n',dimension);
        end
        
        function crop_manual(postPhasor)  
            for jj = 3:-1:2
                figure; 
                imagesc(squeeze(sum(abs(postPhasor.object),jj)));

                hIm = imrect;

                pos = round(getPosition(hIm)); %[xmin ymin width height]                        

                for ii = 1:size(postPhasor.object,jj)      
                    if jj == 3
                        temp.object(:,:,ii) = squeeze(postPhasor.object(pos(2):pos(2)+pos(4),pos(1):pos(1)+pos(3),ii));   
                        temp.mask(:,:,ii) = squeeze(postPhasor.mask(pos(2):pos(2)+pos(4),pos(1):pos(1)+pos(3),ii));   
                    elseif jj == 2
                        temp.object(:,:,ii) = squeeze(postPhasor.object(pos(2):pos(2)+pos(4),ii,pos(1):pos(1)+pos(3)));   
                        temp.mask(:,:,ii) = squeeze(postPhasor.mask(pos(2):pos(2)+pos(4),ii,pos(1):pos(1)+pos(3)));   
                    end
                end
                postPhasor.object = temp.object;
                postPhasor.mask = temp.mask;
                clear temp
                close;
            end
            
            postPhasor.update_plotting_vectors;
            
        end
        
        function apodize(postPhasor,window_type,window_width)
            % In frequency domain
%             if nargin == 1
%                 window_type = 'Tukey';
%                 window_width = 0.9;            
%             end
            
            switch window_type
                case 'Tukey'
                    tukeyx=tukeywin(size(postPhasor.object,1),window_width); %1D window
                    tukeyy=tukeywin(size(postPhasor.object,2),window_width);
                    tukeyz=tukeywin(size(postPhasor.object,3),window_width);

                    tukey2=ones(size(postPhasor.object,1),size(postPhasor.object,2));
                    window=ones(size(postPhasor.object,1),size(postPhasor.object,2),size(postPhasor.object,3));

                    for i=1:size(postPhasor.object,1)              % there is probably a much better way to compute this
                        tukey2(i, :)=tukeyx(i).*tukeyy;
                        for j=1:size(postPhasor.object,2)
                            window(i, j, :)=tukey2(i, j).*tukeyz;
                        end
                    end
            end
            fft_object = fftNc(postPhasor.object);
            fft_max = max(abs(fft_object(:)));
            fft_window = fftNc(postPhasor.object).*window;
            fft_window = fft_window.*fft_max./max(abs(fft_window(:)));
            postPhasor.object = ifftNc(fft_window);   
            fprintf('Object is apodized by %s window of %.2f width\n',window_type,window_width);
        end
        
        function center_data(postPhasor)
            if ~isempty(postPhasor.data)
                [postPhasor.data,center] = center_array_com(postPhasor.data);
                fprintf('Data centered at [%.2f %.2f %.2f]\n',(center));
            else
                error('No data found!')
            end
        end
        
        function center_object(postPhasor)
            [postPhasor.object, com_val] = center_array_com(postPhasor.object);            
            disp('Object centered!');
        end
        
        function transform2lab(postPhasor)
            switch postPhasor.experiment.beamline
                case '34idc'
                    DCS_to_SS;
                case 'P10' 
            end                       
            
            postPhasor.update_plotting_vectors;
        end
        
        function add_pi(postPhasor)
            postPhasor.object = postPhasor.object.*exp(1j*pi);
            disp('+pi value is added to the phase of the object')
        end
        
        function calculate_strain(postPhasor, strain_axis)
            H = 2*pi/postPhasor.experiment.d_spacing;

            postPhasor.displacement = -angle(postPhasor.object)./H;
            
            if strain_axis < 0
                postPhasor.strain = flip(diff(flip(postPhasor.displacement,abs(strain_axis)),abs(strain_axis))./postPhasor.object_sampling);
            else
                postPhasor.strain = flip(diff(postPhasor.displacement,strain_axis)./postPhasor.object_sampling);
            end
            
            mask_shift = [0,0,0];
            mask_shift(abs(strain_axis)) = 1;

            if abs(strain_axis) == 1
                postPhasor.strain_mask = postPhasor.mask(1:end-1,:,:);
            end

            postPhasor.strain_mask = postPhasor.strain_mask+circshift(postPhasor.strain_mask,mask_shift);
            postPhasor.strain_mask = postPhasor.strain_mask == 2;
            
            postPhasor.update_plotting_vectors;
        end
        
        function calculate_strain_unwrap(postPhasor, strain_axis)
            %jclark
            %unwrap based on diff and cumsum
            %drc is direction

            if exist('strain_axis') ~= 1
                strain_axis = 1;
            end
            strain_axis_unwrap = abs(strain_axis);
            %pad the dimension
            temp=exp(1j*pad_by_one(angle(postPhasor.object),strain_axis_unwrap));

            switch strain_axis_unwrap
                case 1
                    phdiff=circshift(temp,-1).*conj(temp);
                case 2
                    phdiff=circshift(temp,[0 -1]).*conj(temp);
                case 3
                    phdiff=circshift(temp,[0 0 -1]).*conj(temp);
                case 4
                    phdiff=circshift(temp,[0 0 0 -1]).*conj(temp);
            end

            %calc the derivative of phase
            temp=angle(phdiff);

            %now do the cumsum
            temp=cumsum(temp,strain_axis_unwrap);
            
            switch strain_axis_unwrap
                case 1
                    temp=circshift(temp,1);
                case 2

                    temp=circshift(temp,[0,1]);
                case 3

                    temp=circshift(temp,[0,0,1]);
                case 4

                    temp=circshift(temp,[0,0,0,1]);
            end
            %now get original size
            phase = crop_by_one(temp,strain_axis_unwrap);
            
            H = 2*pi/postPhasor.experiment.d_spacing;
            postPhasor.displacement = -phase./H;
            
            if strain_axis < 0
                postPhasor.strain = flip(diff(flip(postPhasor.displacement,abs(strain_axis)),abs(strain_axis))./postPhasor.object_sampling);
            else
                postPhasor.strain = flip(diff(postPhasor.displacement,strain_axis)./postPhasor.object_sampling);
            end
            
            mask_shift = [0,0,0];
            mask_shift(abs(strain_axis)) = 1;

            if abs(strain_axis) == 1
                postPhasor.strain_mask = postPhasor.mask(1:end-1,:,:);
            end

            postPhasor.strain_mask = postPhasor.strain_mask+circshift(postPhasor.strain_mask,mask_shift);
            postPhasor.strain_mask = postPhasor.strain_mask == 2;
            
            postPhasor.update_plotting_vectors;
        end
        
        function calculate_prtf(postPhasor)
            % [IN DEVELOPMENT]
            if exist('np') ~= 1
                np=1;
            end
            
            if ~exist(postPhasor.experiment.data_path)
                error('No data path found!')
            else
                try
                    load_data_mat(postPhasor);
                catch
                    error('Can not load the data!')
                end
            end                           

            %get pixel sizes direction
            angxy=(postPhasor.experiment.sample_detector_d.*postPhasor.experiment.wavelength)./[size(postPhasor.data,1),size(postPhasor.data,2)]./postPhasor.experiment.detector_pitch;

            angz=(postPhasor.experiment.wavelength)./sind(size(postPhasor.data,3).*postPhasor.experiment.angular_step);

            rescaledxy=round(angxy/angz.*[size(postPhasor.data,1),size(postPhasor.data,2)]);

            FOVxy=angxy.*[size(postPhasor.data,1),size(postPhasor.data,2)];
            FOVz=angz*size(postPhasor.data,3);

            scalef=FOVxy/FOVz;

            newz=round(scalef*size(postPhasor.data,3));           

            Ipnm=(abs(fftshift(fftn(fftshift(postPhasor.object)))).^2);
%             Ipnm=convn(abs(fftshift(fftn(fftshift(pn)))).^2,params.coh,'same');

            Ipnm(Ipnm <0)=0;

            %get a threshold for fter shifting/sampling
            th=min(postPhasor.data(postPhasor.data ~= 0));

            %pp=0;
            %for qq=1:2:size(Ipnm,3)
            %    pp=pp+1;
            %    Ipnmn(:,:,pp)=sum(Ipnm(:,:,qq:qq+1),3);
            %    datan(:,:,pp)=sum(data(:,:,qq:qq+1),3);
            %end

            %fft and crop/pad to get same sampling
            %Ipnmn=abs(fftshift(fftn(fftshift(zero_pad_ver3(fftshift(ifftn(fftshift(Ipnm))),size(Ipnm,2),size(Ipnm,1),62)))));
            %datan=abs(fftshift(fftn(fftshift(zero_pad_ver3(fftshift(ifftn(fftshift(data))),size(Ipnm,2),size(Ipnm,1),62)))));

            xyz=center_of_mass(postPhasor.data);
            postPhasor.data=circshift(postPhasor.data,-round([xyz(2),xyz(1),xyz(3)]));
            Ipnm=circshift(Ipnm,-round([xyz(2),xyz(1),xyz(3)]));

            %change th FOV to be the same so the sampling is the same
            %Ipnmn=abs(fftshift(fftn(fftshift(zero_pad_ver3(fftshift(ifftn(fftshift(Ipnm))),size(Ipnm,2),size(Ipnm,1),newz(1))))));
            %datan=abs(fftshift(fftn(fftshift(zero_pad_ver3(fftshift(ifftn(fftshift(data))),size(Ipnm,2),size(Ipnm,1),newz(1))))));
            %now sampling is the same as dx dy
            %Ipnm=Ipnmn;
            %data=datan;

            %normalize
            Ipnm=Ipnm./sum(Ipnm(:))*sum(postPhasor.data(:));

            %sqrt of data
            Ipnm=sqrt(Ipnm);
            postPhasor.data=sqrt(postPhasor.data);

            %threshold
            postPhasor.data(postPhasor.data < th)=0;

            ratio=Ipnm./postPhasor.data;

            ratio(isnan(ratio)) = 0;
            ratio(isinf(ratio)) = 0;
            ratio(ratio > 2) = 1;

            ratio=abs(fftshift(fftn(fftshift(zero_pad_ver3(fftshift(ifftn(fftshift(ratio))),size(Ipnm,2),size(Ipnm,1),newz(1))))));

            nd=max(size(ratio));
            ratio=zero_pad_ver3(ratio,nd,nd,nd);

            ratio(ratio < .01)=0;
            ratio(isnan(ratio)) = 0;

            rad=1:(round(nd(1)));

            parfor qq=2:numel(rad)
                fprintf('Calculating shell %d out of %d\n',qq,numel(rad));
                [ circ ] = generate_sphere(nd(1),rad(qq))-generate_sphere(nd(1),rad(qq-1));

                circ0=circ.*(ratio > 0);

                ind=find(circ0 == 1);

                prtf(qq)=sum((ratio(ind)))./numel(ind(:));

%                 ind0=find(circ == 1);
%                 prt0(qq)=sum((ratio(ind0)))./numel(ind0(:));

            end
            postPhasor.prtf.values = prtf;
            postPhasor.prtf.q_spacing = 2*pi*postPhasor.experiment.detector_pitch./postPhasor.experiment.wavelength./postPhasor.experiment.sample_detector_d;
        end
        
        function calculate_resolution(postPhasor)
            % [IN DEVELOPMENT]
        end
        % Visualization %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function plot_prtf(postPhasor)
            figure;
            try                
                plot(postPhasor.prtf);hold on;
                yline(1/exp(1));
            catch
                error('No prtf found!');
            end
        end
        
        function slice3d_object(postPhasor)
            vis3d(double(angle(postPhasor.object)), abs(postPhasor.object)>0.1);
        end
                
        function iso3d_object(postPhasor,input,cmap)
            % Use an input parameter to show other complex valued matrix
            if nargin == 1
                cmap = 'jet';
                input = postPhasor.object./max(max(max(abs(postPhasor.object))));       
                input = input.*postPhasor.support;
            elseif nargin == 2
                cmap = 'jet';                
            end            
            handle = figure;            
            panel = uipanel('Parent',handle,'Title','Amp_Phase','FontSize',...
            12,'Units','Normalized','Position',[.1 0.1 .77 .85]);         
            ax = axes('Parent',panel);
            uicontrol('Parent',handle,'Style',...
            'slider','Min',0,'Max',1,...
            'Value',0.5,'Units','Normalized',...
            'Position', [0.1 0.05 0.3 0.03],...
            'Callback', @slideIsosurfaceReal); 
            isoVal = 0.5;
            drawIsosurface(input,isoVal,cmap);
            
            function drawIsosurface(input,isoVal,cmap)
                cla(ax);
                axes(ax);
                isosurface(abs(input),isoVal,angle(input));
                xlabel('x, [nm]'); ylabel('y, [nm]'); zlabel('z, [nm]'); 
                rotate3d on;
                grid on;
                axis tight;
                axis equal; 
                axis vis3d;
                h3 = light; h3.Position = [-1 -1 -1];  
                h4 = light; h4.Position= [1 1 1];           
                colormap(cmap);
            end
            
            function slideIsosurfaceReal(hObj,callbackdata)
                isoVal = get(hObj,'Value');                 
                drawIsosurface(input,isoVal,cmap);
            end  
        end
        
        function iso3d_data(postPhasor,input,cmap)
            % Use an input parameter to show fft mod of the object
            if nargin == 1
                cmap = 'jet';
                input = log10(postPhasor.data)./max(log10(postPhasor.data(:)));
                title_val = 'Data';
            elseif nargin == 2
                cmap = 'jet';
                input = log10(postPhasor.object_fft_mod)./max(log10(postPhasor.object_fft_mod(:)));
                title_val = 'Reconstruction';
            end
            
            handle = figure;
            panel = uipanel('Parent',handle,'Title',title_val,'FontSize',...
            12,'Units','Normalized','Position',[.1 0.1 .77 .85]); 
        
            ax = axes('Parent',panel);
            uicontrol('Parent',handle,'Style',...
            'slider','Min',0,'Max',1,...
            'Value',0.5,'Units','Normalized',...
            'Position', [0.1 0.05 0.3 0.03],...
            'Callback', @slideIsosurfaceReal); 
            isoVal = 0.5;
            drawIsosurface(input,isoVal);
            
            function drawIsosurface(input,isoVal)
                cla(ax);
                axes(ax);
                isosurface(input,isoVal);                
                rotate3d on;
                grid on;
                axis tight;
                axis equal; 
%                 axis vis3d;
                h3 = light; h3.Position = [-1 -1 -1];  
                h4 = light; h4.Position= [1 1 1];            
                colormap(cmap);                 
            end
            
            function slideIsosurfaceReal(hObj,callbackdata)
                isoVal = get(hObj,'Value');                 
                drawIsosurface(input,isoVal);
            end  
        end
        
        function plot_amplitude_slice(postPhasor)            
            figure('Position',[100 100 2000 500]);
            subplot(1,3,1);imagesc(postPhasor.plotting.object.vector2,postPhasor.plotting.object.vector1,abs(postPhasor.object(:,:,round(end/2))));
            axis image;title('Amplitude, dimensions [1,2]');xlabel('Position [nm]');ylabel('Position [nm]');
            set(gca,'FontSize',20);

            subplot(1,3,2);imagesc(postPhasor.plotting.object.vector3,postPhasor.plotting.object.vector1,squeeze(abs(postPhasor.object(:,round(end/2),:))));
            axis image;title('Amplitude, dimensions [1,3]');xlabel('Position [nm]');ylabel('Position [nm]');
            set(gca,'FontSize',20);

            subplot(1,3,3);imagesc(postPhasor.plotting.object.vector3,postPhasor.plotting.object.vector2,squeeze(abs(postPhasor.object(round(end/2),:,:))));
            axis image;title('Amplitude, dimensions [2,3]');xlabel('Position [nm]');ylabel('Position [nm]');
            colormap bone
            set(gca,'FontSize',20);
        end
        
        function plot_phase_slice(postPhasor)            
            % Phase central slices
            figure('Position',[100 100 2000 500]);
            subplot(1,3,1);imagesc(postPhasor.plotting.object.vector2,postPhasor.plotting.object.vector1,...
                angle(postPhasor.object(:,:,round(end/2))).*postPhasor.mask(:,:,round(end/2)),'AlphaData',postPhasor.mask(:,:,round(end/2)));
            axis image;title('Phase');colorbar;xlabel('Position [nm]');ylabel('Position [nm]');
            set(gca,'FontSize',20);

            subplot(1,3,2);imagesc(postPhasor.plotting.object.vector3,postPhasor.plotting.object.vector1,...
                squeeze(angle(postPhasor.object(:,round(end/2),:))).*squeeze(postPhasor.mask(:,round(end/2),:)),'AlphaData',squeeze(postPhasor.mask(:,round(end/2),:)));
            axis image;title('Phase');colorbar;xlabel('Position [nm]');ylabel('Position [nm]');
            set(gca,'FontSize',20);

            subplot(1,3,3);imagesc(postPhasor.plotting.object.vector3,postPhasor.plotting.object.vector2,...
                squeeze(angle(postPhasor.object(round(end/2),:,:))).*squeeze(postPhasor.mask(round(end/2),:,:)),'AlphaData',squeeze(postPhasor.mask(round(end/2),:,:)));
            axis image;title('Phase');colorbar;xlabel('Position [nm]');ylabel('Position [nm]');
            set(gca,'FontSize',20);
            colormap jet
        end
        
        function plot_displacement_slice(postPhasor)            
            % Phase central slices
            figure('Position',[100 100 2000 500]);
            subplot(1,3,1);imagesc(postPhasor.plotting.object.vector2,postPhasor.plotting.object.vector1,(postPhasor.displacement(:,:,round(end/2))).*postPhasor.mask(:,:,round(end/2)),'AlphaData',postPhasor.mask(:,:,round(end/2)));
            axis image;title('Displacement');colorbar;xlabel('Position [nm]');ylabel('Position [nm]');
            set(gca,'FontSize',20);
            
            subplot(1,3,2);imagesc(postPhasor.plotting.object.vector3,postPhasor.plotting.object.vector1,squeeze((postPhasor.displacement(:,round(end/2),:))).*squeeze(postPhasor.mask(:,round(end/2),:)),'AlphaData',squeeze(postPhasor.mask(:,round(end/2),:)));
            axis image;title('Displacement');colorbar;xlabel('Position [nm]');ylabel('Position [nm]');
            set(gca,'FontSize',20);
            
            subplot(1,3,3);imagesc(postPhasor.plotting.object.vector3,postPhasor.plotting.object.vector2,squeeze((postPhasor.displacement(round(end/2),:,:))).*squeeze(postPhasor.mask(round(end/2),:,:)),'AlphaData',squeeze(postPhasor.mask(round(end/2),:,:)));
            axis image;title('Displacement');colorbar;xlabel('Position [nm]');ylabel('Position [nm]');
            colormap jet
            set(gca,'FontSize',20);
        end
        
        function plot_strain_slice(postPhasor)
            try
                figure('Position',[100 100 2000 500]);
                subplot(1,3,1);
                imagesc(postPhasor.plotting.strain.vector2,...
                        postPhasor.plotting.strain.vector1(2:end),...
                        postPhasor.strain(:,:,round(end/2)).*postPhasor.strain_mask(:,:,round(end/2)),...
                        'AlphaData',postPhasor.strain_mask(:,:,round(end/2)));                    
                axis image;colorbar;colorbar;title('Strain');xlabel('Position [nm]');ylabel('Position [nm]');
                set(gca,'FontSize',20);

                subplot(1,3,2);
                imagesc(postPhasor.plotting.strain.vector3,...
                        postPhasor.plotting.strain.vector1(2:end),...
                        squeeze(postPhasor.strain(:,round(end/2),:)).*squeeze(postPhasor.strain_mask(:,round(end/2),:)),...
                        'AlphaData',squeeze(postPhasor.strain_mask(:,round(end/2),:)));
                axis image;colorbar;colorbar;title('Strain');xlabel('Position [nm]');ylabel('Position [nm]');
                set(gca,'FontSize',20);

                subplot(1,3,3);
                imagesc(postPhasor.plotting.strain.vector3,...
                        postPhasor.plotting.strain.vector2,...
                        squeeze(postPhasor.strain(round(end/2),:,:)).*squeeze(postPhasor.strain_mask(round(end/2),:,:)),...
                        'AlphaData',squeeze(postPhasor.strain_mask(round(end/2),:,:)));
                axis image;colorbar;colorbar;title('Strain');xlabel('Position [nm]');ylabel('Position [nm]');
                set(gca,'FontSize',20);
                colormap jet
            catch
                error('No strain found!')
            end
        end
        
        function plot_central_profiles(postPhasor,volume)
            if ~exist('volume','var')
                volume = 'all';
            end
            
            if ismember(volume,['amplitude', 'all'])
                figure('Position',[100 100 2000 500]);
                subplot(1,3,1);
                val = squeeze(abs(postPhasor.object(:,round(end/2),round(end/2))));
                val_contour = squeeze((postPhasor.mask(:,round(end/2),round(end/2)))).*max(val(:));
                val_contour_mask = val_contour>0;
                val_contour_length = sum(val_contour_mask).*postPhasor.object_sampling;
                
                plot(postPhasor.plotting.object.vector1,val,'.-');hold on
                plot(postPhasor.plotting.object.vector1,val_contour,'--');
                title(sprintf('Amplitude profile: %.2f nm',val_contour_length*1e9));
                grid on;xlabel('Position [nm]');set(gca,'FontSize',20);

                subplot(1,3,2);
                val = squeeze(abs(postPhasor.object(round(end/2),:,round(end/2))));
                val_contour = squeeze((postPhasor.mask(round(end/2),:,round(end/2)))).*max(val(:));                
                val_contour_mask = val_contour>0;
                val_contour_length = sum(val_contour_mask).*postPhasor.object_sampling;
                plot(postPhasor.plotting.object.vector2,val,'.-');hold on
                plot(postPhasor.plotting.object.vector2,val_contour,'--');
                title(sprintf('Amplitude profile: %.2f nm',val_contour_length*1e9));
                grid on;xlabel('Position [nm]');set(gca,'FontSize',20);

                subplot(1,3,3);
                val = squeeze(abs(postPhasor.object(round(end/2),round(end/2),:)));
                val_contour = squeeze(postPhasor.mask(round(end/2),round(end/2),:)).*max(val(:));
                val_contour_mask = val_contour>0;
                val_contour_length = sum(val_contour_mask).*postPhasor.object_sampling;
                plot(postPhasor.plotting.object.vector3,val,'.-');hold on
                plot(postPhasor.plotting.object.vector3,val_contour,'--');
                title(sprintf('Amplitude profile: %.2f nm',val_contour_length*1e9));
                grid on;xlabel('Position [nm]');set(gca,'FontSize',20);
            end
            if ismember(volume,['phase', 'all'])       
                figure;
                subplot(1,3,1);
                val = squeeze(angle(postPhasor.object(:,round(end/2),round(end/2))));
                plot(postPhasor.plotting.object.vector1,val,'.-');hold on
                plot(postPhasor.plotting.object.vector1,squeeze((postPhasor.mask(:,round(end/2),round(end/2)))).*max(val(:)),'--');
                title('Phase profile');grid on;xlabel('Position [nm]');

                subplot(1,3,2);
                val = squeeze(angle(postPhasor.object(round(end/2),:,round(end/2))));
                plot(postPhasor.plotting.object.vector2,val,'.-');hold on
                plot(postPhasor.plotting.object.vector2,squeeze((postPhasor.mask(round(end/2),:,round(end/2)))).*max(val(:)),'--');
                title('Phase profile');grid on;xlabel('Position [nm]');

                subplot(1,3,3);
                val = squeeze(angle(postPhasor.object(round(end/2),round(end/2),:)));
                plot(postPhasor.plotting.object.vector3,val,'.-');hold on
                plot(postPhasor.plotting.object.vector3,squeeze(postPhasor.mask(round(end/2),round(end/2),:)).*max(val(:)),'--');
                title('Phase profile');grid on;xlabel('Position [nm]');
            end
            if ismember(volume,['displacement', 'all'])            
                figure;
                subplot(1,3,1);
                val = squeeze(postPhasor.displacement(:,round(end/2),round(end/2)));
                plot(postPhasor.plotting.object.vector1,val,'.-');hold on
                plot(postPhasor.plotting.object.vector1,squeeze((postPhasor.mask(:,round(end/2),round(end/2)))).*max(val(:)),'--');
                title('Displacement profile');grid on;xlabel('Position [nm]');

                subplot(1,3,2);
                val = squeeze(postPhasor.displacement(round(end/2),:,round(end/2)));
                plot(postPhasor.plotting.object.vector2,val,'.-');hold on
                plot(postPhasor.plotting.object.vector2,squeeze((postPhasor.mask(round(end/2),:,round(end/2)))).*max(val(:)),'--');
                title('Displacement profile');grid on;xlabel('Position [nm]');

                subplot(1,3,3);
                val = squeeze(postPhasor.displacement(round(end/2),round(end/2),:));
                plot(postPhasor.plotting.object.vector3,val,'.-');hold on
                plot(postPhasor.plotting.object.vector3,squeeze(postPhasor.mask(round(end/2),round(end/2),:)).*max(val(:)),'--');
                title('Displacement profile');grid on;xlabel('Position [nm]');
            end
            if ismember(volume,['strain', 'all'])      
                figure;
                subplot(1,3,1);
                val = squeeze(postPhasor.strain(:,round(end/2),round(end/2)));
                plot(postPhasor.plotting.strain.vector1,val,'.-');hold on
                plot(postPhasor.plotting.strain.vector1,squeeze((postPhasor.strain_mask(:,round(end/2),round(end/2)))).*max(val(:)),'--');
                title('Strain profile');grid on;xlabel('Position [nm]');

                subplot(1,3,2);
                val = squeeze(postPhasor.strain(round(end/2),:,round(end/2)));
                plot(postPhasor.plotting.strain.vector2,val,'.-');hold on
                plot(postPhasor.plotting.strain.vector2,squeeze((postPhasor.strain_mask(round(end/2),:,round(end/2)))).*max(val(:)),'--');
                title('Strain profile');grid on;xlabel('Position [nm]');

                subplot(1,3,3);
                val = squeeze(postPhasor.strain(round(end/2),round(end/2),:));
                plot(postPhasor.plotting.strain.vector3,val,'.-');hold on
                plot(postPhasor.plotting.strain.vector3,squeeze(postPhasor.strain_mask(round(end/2),round(end/2),:)).*max(val(:)),'--');
                title('Strain profile');grid on;xlabel('Position [nm]');    
            end            
        end
        % Save functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % save the current instance of the object
        function save_all(postPhasor)      
            postPhasor.dataTime = getTimeStamp;                        
            save_path = fullfile(postPhasor.path, 'post_processing');
            save_path_figures = fullfile(save_path, 'figures');
            
            mkdir(save_path);
            mkdir(save_path_figures);
            
            savemat2vtk(fullfile(save_path, 'object.vtk'),      postPhasor.object.*postPhasor.mask,     postPhasor.object_sampling);
            savemat2vtk(fullfile(save_path, 'displacement.vtk'),postPhasor.mask,                        postPhasor.object_sampling,     postPhasor.displacement.*postPhasor.mask);
            savemat2vtk(fullfile(save_path, 'strain.vtk'),      postPhasor.strain_mask,                 postPhasor.object_sampling,     postPhasor.strain.*postPhasor.strain_mask);
            
            % Save the whole instance
            save(fullfile(save_path, sprintf('postPhasor_%s.mat',postPhasor.dataTime)),'postPhasor');
            
            % Figures
            postPhasor.plot_amplitude_slice();
            hFig = gcf;
            set(hFig,'Units','Inches');
            pos = get(hFig,'Position');
            set(hFig,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3), pos(4)]);
            print(hFig,fullfile(save_path_figures,'amplitude_slice.pdf'),'-dpdf','-r0');
            print(hFig,fullfile(save_path_figures,'amplitude_slice.png'),'-dpng','-r0');
            close(hFig);
            
            postPhasor.plot_phase_slice();
            hFig = gcf;
            set(hFig,'Units','Inches');
            pos = get(hFig,'Position');
            set(hFig,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3), pos(4)]);
            print(hFig,fullfile(save_path_figures,'phase_slice.pdf'),'-dpdf','-r0');
            print(hFig,fullfile(save_path_figures,'phase_slice.png'),'-dpng','-r0');
            close(hFig);
            
            postPhasor.plot_strain_slice();
            hFig = gcf;
            set(hFig,'Units','Inches');
            pos = get(hFig,'Position');
            set(hFig,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3), pos(4)]);
            print(hFig,fullfile(save_path_figures,'strain_slice.pdf'),'-dpdf','-r0');
            print(hFig,fullfile(save_path_figures,'strain_slice.png'),'-dpng','-r0');
            close(hFig);
            
            postPhasor.plot_displacement_slice();
            hFig = gcf;
            set(hFig,'Units','Inches');
            pos = get(hFig,'Position');
            set(hFig,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3), pos(4)]);
            print(hFig,fullfile(save_path_figures,'displacement_slice.pdf'),'-dpdf','-r0');
            print(hFig,fullfile(save_path_figures,'displacement_slice.png'),'-dpng','-r0');
            close(hFig);
            
            postPhasor.plot_central_profiles('amplitude');
            hFig = gcf;
            set(hFig,'Units','Inches');
            pos = get(hFig,'Position');
            set(hFig,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3), pos(4)]);
            print(hFig,fullfile(save_path_figures,'amplitude_central_profiles.pdf'),'-dpdf','-r0');
            print(hFig,fullfile(save_path_figures,'amplitude_central_profiles.png'),'-dpng','-r0');
            close(hFig);
            
            fprintf('Saved everything to: %s\n',save_path);
        end
                
    end
end
