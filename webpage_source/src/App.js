import { useState } from 'react';

import url_data from './data';

import './App.css';
import 'react-toastify/dist/ReactToastify.css';

import r_lang from './assets/r_lang.png';
import logo from './assets/logo.png';

import { Helmet } from "react-helmet";

import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faArrowCircleRight } from '@fortawesome/free-solid-svg-icons';
import { ToastContainer, toast } from 'react-toastify';



import Modal from 'react-modal';

const Section = ({url, name, func}) => {
  return (
    <div href={url} onClick={() => func()}>
      <section className="section">
        <img src={r_lang} className="r_langlogo" alt=" programming languague logo's" />
        <h4>{name}</h4>
        <div className="back_button">
          <FontAwesomeIcon className="backlogo" icon={faArrowCircleRight} />
        </div>
      </section>
    </div>
  )
}

const ModalTag = ({isModalOpen,setIsModalOpen,sendRequest}) => {

  const customStyles = {
    content: {
      top: '50%',
      left: '50%',
      right: 'auto',
      bottom: 'auto',
      marginRight: '-50%',
      transform: 'translate(-50%, -50%)',
      borderRadius: '30px',
      padding: '40px'
    },
  };
  return (
    <Modal
      isOpen={isModalOpen}
      onRequestClose={() => setIsModalOpen(false)}
      contentLabel="Example Modal"
      style={customStyles}
      ariaHideApp={false}>
      <form id="modal-email" onSubmit={sendRequest}>
        <h2>Please insert your email address</h2>
        <input class="modal_input" name="email" type="email" required />
        <button class="modal_btn" onSubmit={()=>console.log("")}>Go to Markdown</button>
      </form>
    </Modal>
  )
}

//        
const App = () => {

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedMarkdown,setSelectedMarkdown] = useState()

  const sendRequest = (e) => {
    e.preventDefault();
    const email = e.target[0].value;
    toast.success("Email saved!");
    console.log(selectedMarkdown)
    window.location.href = window.location.href+selectedMarkdown["url"]+`?email=${email}`
  }

  return (
    <>
    <Helmet>
      <title>RMarkdowns</title>
      <meta name="description" content="RMarkdowns" />
    </Helmet>
    <ToastContainer/>
    <div>
      
      {isModalOpen && 
        <ModalTag 
        isModalOpen={isModalOpen}
        setIsModalOpen={setIsModalOpen}
        sendRequest={sendRequest}/>
      }
      <div id="title">
        <figure>
          <a href="/">
          <img src={logo} id="title_img" alt="Informatica Educativa Logo" />
          </a>
        </figure>
        Markdowns
      </div>


      <div id="content">
        {url_data.map((e) => (
          <Section
            url={e.url}
            name={e.name}
            func={() => {
              setSelectedMarkdown(e)
              setIsModalOpen(true)
            }}
            key={e.url}
            
            />
        ))
        }
      </div>
    </div>
    </>
  )
}

export default App;
