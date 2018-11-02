import { Component, OnInit, Input } from '@angular/core';
import { Media } from '../media';

@Component({
  selector: 'app-media-section',
  templateUrl: './media-section.component.html',
  styleUrls: ['./media-section.component.scss']
})
export class MediaSectionComponent implements OnInit {

  @Input() title: string;
  @Input('playbackSource') episodes: Media[];

  constructor() { }

  ngOnInit() {
  }

}
